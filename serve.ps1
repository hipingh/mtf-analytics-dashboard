# Simple PowerShell HTTP Server for MTF Analytics Dashboard
$port = 8080
$path = Join-Path $PSScriptRoot "public"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")

try {
    $listener.Start()
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host " MTF Analytics Dashboard Local Server" -ForegroundColor Green
    Write-Host " URL: http://localhost:$port/" -ForegroundColor Yellow
    Write-Host " Serving directory: $path" -ForegroundColor Gray
    Write-Host " Press Ctrl+C to stop the server" -ForegroundColor Gray
    Write-Host "=======================================================" -ForegroundColor Cyan

    # Open browser automatically
    Start-Process "http://localhost:$port/"

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $rawUrl = $request.Url.LocalPath
        if ($rawUrl -eq "/" -or $rawUrl -eq "") {
            $rawUrl = "/index.html"
        }

        $localFilePath = Join-Path $path ($rawUrl.TrimStart('/'))

        if (Test-Path $localFilePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($localFilePath).ToLower()
            $contentType = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".json" { "application/json; charset=utf-8" }
                ".svg"  { "image/svg+xml" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                default { "application/octet-stream" }
            }

            $bytes = [System.IO.File]::ReadAllBytes($localFilePath)
            $response.ContentType = $contentType
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $rawUrl")
            $response.OutputStream.Write($msg, 0, $msg.Length)
        }
        $response.OutputStream.Close()
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
