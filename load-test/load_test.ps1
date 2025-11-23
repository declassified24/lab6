param(
    [string]$TargetUrl = "http://127.0.0.1",
    [int]$Duration = 120
)

Write-Host "Starting load test for $Duration seconds..." -ForegroundColor Green
$startTime = Get-Date
$endTime = $startTime.AddSeconds($Duration)
$success = 0
$errors = 0
$requestCount = 0

while ((Get-Date) -lt $endTime) {
    $requestCount++
    try {
        $response = Invoke-WebRequest -Uri $TargetUrl -TimeoutSec 3
        $success++
        Write-Host "." -NoNewline -ForegroundColor Green
    } catch {
        $errors++
        Write-Host "E" -NoNewline -ForegroundColor Red
    }
    
    if ($requestCount % 15 -eq 0) {
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        $remaining = [math]::Round(($endTime - (Get-Date)).TotalSeconds, 1)
        $rps = [math]::Round($requestCount / $elapsed, 1)
        Write-Host " ($elapseds | ${remaining}s left | RPS:$rps)" -ForegroundColor Gray
    }
    
    Start-Sleep -Milliseconds 30
}

Write-Host "
" + "="*50 -ForegroundColor White
Write-Host "LOAD TEST COMPLETED" -ForegroundColor White
Write-Host "="*50 -ForegroundColor White
Write-Host "Duration: $Duration seconds" -ForegroundColor Cyan
Write-Host "Total requests: $requestCount" -ForegroundColor Cyan
Write-Host "Successful: $success" -ForegroundColor Green
Write-Host "Errors: $errors" -ForegroundColor Red
$successRate = if ($requestCount -gt 0) { ($success / $requestCount * 100) } else { 0 }
Write-Host "Success rate: $([math]::Round($successRate, 1))%" -ForegroundColor Cyan
Write-Host "Requests per second: $([math]::Round($requestCount / $Duration, 1))" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor White
