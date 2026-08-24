# Subject: Take-Home Assignment Submission: MTF Analytics Dashboard - [Your Name]

Dear Hiring Team,

Thank you for the opportunity to work on the **MTF Analytics Dashboard** take-home assignment. I have completed both **Part A (Interactive Overview Dashboard Rebuild)** and **Part B (End-to-End Platform Architecture Plan)**.

Below are the submission links and a brief summary of the work:

---

### 🔗 Submission Deliverables
* **Live Deployed URL:** `https://your-deployment-url.vercel.app` *(Replace with your live deployed URL)*
* **GitHub Repository:** `https://github.com/your-username/mtf-analytics-dashboard` *(Replace with your repo URL)*
* **Part B Platform Plan (Design Doc):** [`platform_plan.md`](./platform_plan.md) *(also embedded interactively in the app header)*
* **Technical README & Architecture Notes:** [`README.md`](./README.md)

---

### 🌟 Part A: Key Highlights of the Redesign (Overview Tab)
1. **Original UI & Information Hierarchy:** Redesigned from the ground up with a modern financial terminal aesthetic, high-contrast dark & light themes, and zero aesthetic cloning of the original website.
2. **Macro Headline Card:** Displays the combined MTF system book (₹1.49 Lakh Crore / ₹1,48,653.99 Cr as of 20 Aug 2026), 1-day change, trailing 30-day growth, All-Time High distance, and an interactive NSE vs BSE split bar.
3. **60 FPS Hardware-Accelerated Chart:** Built using custom 2D Canvas rendering over 2,250+ historical trading days (June 2017 to August 2026), supporting timeframe toggles (`1M`, `3M`, `1Y`, `ALL`), exchange filters (`Both`, `NSE`, `BSE`), and Net Margin Flow mode with dynamic crosshairs.
4. **Multi-Angle Breakdown Engine:** Interactive tabs for **Asset Composition** (F&O vs Non-F&O vs ETF), **Market Cap Buckets** (Large/Mid/Small/Micro), **Sector Exposure**, and **Leverage Fragility**.
5. **High-Density Stock Screener Table:** Searchable, sortable across all metrics, paginated with density controls, CSV export, and a slide-over stock inspection drawer.
6. **Strict Indian Rupee Formatting:** Accurate formatting across Lakhs, Crores, Lakh Crores, and Indian digit grouping (`12,34,567.89`).

---

### 📐 Part B: Platform Plan Summary
The 2-page engineering design document [`platform_plan.md`](./platform_plan.md) covers:
* **Ingestion Pipeline:** Robust handling of NSE/BSE Excel/CSV format variations, staggered publication times (18:30 vs 21:00 IST), trading holidays, forward-filling for asymmetric publishing, and dead-letter queues.
* **9-Year Backfill:** High-throughput 16-worker parallel ingestion completing all 6 million rows in ~7.5 minutes.
* **Identity Resolution:** Master Security resolution using immutable ISIN keys to resolve symbol renames and exchange code discrepancies (`TMPV` vs `500570`).
* **Sub-25ms Serving Architecture:** Precomputed static JSON at CDN edge + client in-memory slicing, minimizing cloud costs to **$18–$45/month**.
* **Data Correctness:** Dual-entry accounting checks ($Beginning + Fresh - Liquidated \equiv Ending$) and z-score anomaly detection.

---

I enjoyed working on this challenge and look forward to discussing the design decisions, trade-offs, and architecture in the next round.

Best regards,  
**[Your Name]**  
[Your Phone Number]  
[Your LinkedIn Profile]  
[Your Email Address]
