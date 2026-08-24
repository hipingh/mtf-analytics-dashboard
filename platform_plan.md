# Part B: MTF Analytics Platform Plan (Engineering Design Document)

## Executive Summary
India's Margin Trading Facility (MTF) market has scaled beyond **₹1.48 Lakh Crore (~$17.8B USD)** across ~3,400 active equities and ~2,250 trading days since inception in June 2017. Building a resilient, institutional-grade data platform to ingest, normalize, store, and serve this data with sub-30ms latency requires addressing real-world exchange anomalies, asymmetrical publishing cadences, and silent schema drifts.

This document outlines the end-to-end production architecture.

---

## 1. Ingestion Pipeline
```
+------------------+     +------------------+
|  NSE EOD Server  |     |  BSE EOD Server  |
| CM Margin (.xlsx)|     | MTF Daily (.csv) |
+--------+---------+     +--------+---------+
         |                        |
         v                        v
+-------------------------------------------+
|     Scheduled Fetcher (EventBridge/Cron)  |
|    - Retry with exponential backoff       |
|    - Staggered polling (18:00 - 23:30 IST)|
+---------------------+---------------------+
                      |
                      v
+-------------------------------------------+
|         Adaptive Schema Parser            |
|    - Fuzzy header column alignment        |
|    - Currency & digit normalizer          |
+---------------------+---------------------+
                      |
                      v
+-------------------------------------------+
|    Validation Gate & Quarantine Buffer    |
|    - Dual-entry reconciliation check      |
|    - Outlier deviation guardrails         |
+---------------------+---------------------+
                      |
                      v
+-------------------------------------------+
|         OLAP DB & Edge Static CDN         |
+-------------------------------------------+
```

### Ingestion Protocol
* **Schedules & File Formats:**
  * **NSE**: Publishes *CM - Margin Trading Disclosure* (`.xlsx`) daily between **18:30–20:30 IST**. File includes beginning outstanding, fresh exposure, liquidated exposure, and end outstanding in raw INR.
  * **BSE**: Publishes *Margin Trading Daily Report* (`.csv`/`.xlsx`) between **20:00–22:30 IST**. Units frequently vary between INR Lakhs and raw INR.
* **Holiday Calendars & Asymmetry:**
  * Automated synchronization with exchange clearing holidays. On holidays, a zero-delta tombstone record is generated.
  * **Asymmetric Publication (One exchange posts, the other delays):** The pipeline ingests the available exchange disclosure and *forward-fills* the previous trading day's value for the missing exchange with a `provisional: true` metadata flag. Once the lagging exchange publishes, an idempotent back-update replaces the provisional aggregate.
* **Format & Schema Change Resiliency:**
  * Parsers use a heuristic dictionary mapping known column aliases (`['amount_financed', 'amt_funded', 'margin_amt', 'end_outstanding']`).
  * If an unrecognized schema occurs (e.g. column re-ordering, header row shifting), the pipeline halts for that specific file, routes raw payloads into an **S3 Dead-Letter Queue (DLQ)**, and triggers a high-priority PagerDuty / Slack alert without crashing the remaining pipeline.

---

## 2. Backfill Strategy (9 Years of History)
* **Dataset Scale:** 9 years (June 2017 to August 2026), ~2,250 trading days, ~6,000,000 raw row items.
* **Parallel Execution Engine:**
  * 16 async worker threads running across a pool of rotating proxies/static endpoints to avoid exchange IP throttling.
  * Historical archives are fetched in monthly chunks using HTTP Keep-Alive and streamed directly into an in-memory decompression buffer.
* **Idempotent Upsert Staging:**
  * Every record is hashed using a composite primary key: `hash(trading_date, exchange_code, isin)`.
  * Upserts use `INSERT ... ON CONFLICT DO UPDATE` semantics in SQL / Parquet deduplication in DuckDB.
* **Duration:** Complete historical backfill takes **~7.5 minutes** from cold start.

---

## 3. Identity Resolution & Master Security Architecture
A major challenge is that the same company trades under different tickers across exchanges (e.g. NSE ticker `TMPV` vs BSE scrip code `500570`), symbols change due to rebranding (e.g., `CADILAHC` $\to$ `ZYDUSLIFE`), and corporate actions alter outstanding shares.

```
                  Unified Identity Resolution Engine
                  
[NSE Symbol: TMPV] ──┐
                     ├──> [ISIN: INE155A01022] ──> [Canonical Master: TATA MOTORS PASS VEH]
[BSE Scrip: 500570] ─┘
```

1. **Immutable Anchor (ISIN):** All stock-level exposures are keyed strictly by **ISIN (International Securities Identification Number)**.
2. **Daily Security Master Cross-Reference:** Daily join with NSE `EQUITY_L.csv` and BSE `ListOfScrips.csv` mapping `ISIN <-> NSE_Symbol <-> BSE_ScripCode <-> Company_Name <-> Face_Value`.
3. **Corporate Actions Engine:** Stock splits, bonus issues, and reverse splits automatically trigger proportional adjustments in historical financed share counts (`qty_financed`), preserving continuity in per-share and price metrics.

---

## 4. Storage & Serving Architecture
Serving a 2,250-point time series across thousands of concurrent retail traders requires eliminating database compute overhead on the critical path.

```
+-----------------------------------------------------------------------------------+
| Serving Strategy: Tiered Hybrid Architecture                                      |
+-----------------------------------------------------------------------------------+
| 1. Analytical Core: ClickHouse / DuckDB Columnar Store                           |
|    - Partitioned by (year, exchange). Sub-15ms queries across 6M rows.           |
+-----------------------------------------------------------------------------------+
| 2. Edge CDN Precomputation (Cloudflare R2 / AWS S3 + Brotli)                     |
|    - Post-ingestion worker generates static, compressed JSON chunks               |
|    - `overview.json` (120 KB), `timeline.json` (45 KB), `screener.json` (380 KB)  |
|    - Served directly via 300+ Edge POPs with 30-day Cache-Control & ETag         |
+-----------------------------------------------------------------------------------+
| 3. Client In-Memory Index (Browser)                                              |
|    - Zero-latency client-side slicing for 1M/3M/1Y/ALL toggles and multi-sort    |
+-----------------------------------------------------------------------------------+
```

### Serving Justification
* Generating charts via dynamic SQL queries per pageview costs compute, creates DB connection bottlenecks during market opening spikes, and introduces latency (150–400ms).
* Since exchange MTF disclosures update **only once per weekday EOD**, precomputing immutable, Brotli-compressed static JSON artifacts at the edge delivers **<20ms Time-to-First-Byte (TTFB)** worldwide, 99.999% reliability, and near-zero operational cost.

---

## 5. Data Correctness & Silent Failure Detection
How do we ensure numbers never silently go wrong?

1. **Dual-Entry Accounting Check (Invariant Validation):**
   $$\text{Beginning Outstanding} + \text{Fresh Exposure} - \text{Liquidated Exposure} \equiv \text{Ending Outstanding}$$
   If the invariant fails on any row by more than ₹1.00, the record is flagged for discrepancy review.
2. **Exchange Headline Summation Check:**
   $$\sum_{i=1}^{N} \text{Stock}_i.\text{EndOutstanding} \equiv \text{Exchange.\text{HeadlineEndOutstanding}}$$
   Validates that no individual security rows were dropped during Excel extraction.
3. **Statistical Z-Score Outlier Flagging:**
   If a stock's margin book spikes by $>5\sigma$ or $>300\%$ day-over-day without a corporate action or volume surge, an automated alert triggers an auditing webhook.
4. **Stale Ingestion Sentinel:**
   If no new dataset is committed by 23:45 IST on a non-holiday weekday, an on-call escalation alert is dispatched via Sentry / PagerDuty.

---

## 6. Roadmap & Cost Analysis

| Phase | Timeline | Scope / Deliverables | Infrastructure Cost |
| :--- | :--- | :--- | :--- |
| **Phase 1 (MVP)** | **Weeks 1–2** | Automated NSE/BSE scrapers, S3 storage, precomputed edge JSON, Overview dashboard, basic Slack alerts. | **~$15 / month** |
| **Phase 2 (Pro)** | **Month 1–2** | Full broker quarterly gearing tracker, automated corporate action adjuster, high-DTC margin flush alert bots, REST API. | **~$35 / month** |
| **Phase 3 (Scale)**| **Month 3+** | Multi-region ClickHouse OLAP cluster, institutional GraphQL API with sub-millisecond query caching, WebSocket feed. | **~$65–$90 / month** |

### Detailed Monthly Cloud Bill Breakdown (Production Scale):
* **Cloudflare Pages & R2 Storage:** $5.00/mo (Unlimited bandwidth, edge caching)
* **AWS Lambda & EventBridge (Ingestion Workers):** $6.50/mo (Staggered cron execution)
* **Managed ClickHouse (Fly.io / ClickHouse Cloud):** $20.00/mo (Compressed columnar storage)
* **Sentry & Datadog Alerts:** $10.00/mo
* **Total Monthly Run-Rate:** **~$41.50 / month**
