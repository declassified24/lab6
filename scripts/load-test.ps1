#!/usr/bin/env pwsh

Write-Host \"=== KUBERNETES LOAD TEST ===\" -ForegroundColor Cyan
Write-Host \"Starting load test to trigger HPA scaling...\" -ForegroundColor Yellow

$url = \"http://127.0.0.1\"
$duration = 300  # 5 minutes

# Load generation function
$loadScript = {
    param($url, $threadId, $duration)
    
    $endTime = [DateTime]::Now.AddSeconds($duration)
    $client = New-Object System.Net.WebClient
    
    while ([DateTime]::Now -lt $endTime) {
        try {
            $client.DownloadString($url) | Out-Null
        } catch {
            # Ignore errors
        }
    }
}

Write-Host \"Starting 20 parallel load generators...\" -ForegroundColor Green
$jobs = @()
for ($i = 0; $i -lt 20; $i++) {
    $job = Start-Job -ScriptBlock $loadScript -ArgumentList $url, $i, $duration
    $jobs += $job
}

Write-Host \"Load test started! Monitoring progress...\" -ForegroundColor Cyan

# Monitoring
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep 10
    
    Clear-Host
    Write-Host \"=== LOAD TEST PROGRESS ===\" -ForegroundColor Cyan
    Write-Host \"Check $i of 30 | Elapsed: $($i * 10) seconds\" -ForegroundColor White
    
    Write-Host \"\
📊 PODS STATUS:\" -ForegroundColor Yellow
    kubectl get pods -l app=nginx
    
    Write-Host \"\
📈 HPA STATUS:\" -ForegroundColor Yellow
    kubectl get hpa
    
    $podCount = (kubectl get pods -l app=nginx --no-headers | Measure-Object -Line).Lines
    if ($podCount -gt 6) {
        Write-Host \"\
🎉 SUCCESS! HPA SCALING DETECTED: $podCount pods\" -ForegroundColor Green
        break
    }
}

# Cleanup
Write-Host \"\
Stopping load generators...\" -ForegroundColor Yellow
$jobs | Remove-Job -Force

Write-Host \"\
=== FINAL RESULTS ===\" -ForegroundColor Green
kubectl get all -l app=nginx
