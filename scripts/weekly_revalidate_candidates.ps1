$ErrorActionPreference = "Stop"
Set-Location "d:\Ravi\Project\india-election-compass"

Write-Output "[revalidate] Starting candidate reconciliation from public source..."
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/reconcile_alliance_candidates_from_source.ps1"

$tvkCount = (Get-ChildItem "elections/tn/constituencies" -Recurse -Filter "config.json" | Select-String -Pattern '"alias"\s*:\s*"cand-tvk"' | Measure-Object).Count
$indCount = (Get-ChildItem "elections/tn/constituencies" -Recurse -Filter "config.json" | Select-String -Pattern '"alias"\s*:\s*"cand-ind"' | Measure-Object).Count

$stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$line = "$stamp | tvk_alias_files=$tvkCount | ind_alias_files=$indCount"

$logPath = "scripts/revalidation-log.txt"
if (-not (Test-Path $logPath)) {
    "timestamp | tvk_alias_files | ind_alias_files" | Out-File -FilePath $logPath -Encoding UTF8
}
Add-Content -Path $logPath -Value $line -Encoding UTF8

Write-Output "[revalidate] Completed. $line"
Write-Output "[revalidate] Log updated: scripts/revalidation-log.txt"
