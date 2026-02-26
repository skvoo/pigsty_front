# Copy apply_minio_on_server.sh to server and run it (applies ./minio.yml -l minio).
# Run from repo root: .\scripts\run_minio_on_server.ps1
# Requires: SSH access to st@104.223.25.234. If SSH from IDE fails, run the commands in your terminal.

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $PSScriptRoot "apply_minio_on_server.sh"
$serverUser = "st"
$serverHost = "104.223.25.234"

if (-not (Test-Path $scriptPath)) {
  Write-Host "Script not found: $scriptPath" -ForegroundColor Red
  exit 1
}

Write-Host "Copying apply_minio_on_server.sh to ${serverUser}@${serverHost}..." -ForegroundColor Cyan
scp $scriptPath "${serverUser}@${serverHost}:~/"
Write-Host "Running MinIO playbook on server..." -ForegroundColor Cyan
ssh "${serverUser}@${serverHost}" "chmod +x ~/apply_minio_on_server.sh && ~/apply_minio_on_server.sh"
Write-Host "Done. Check MinIO console: http://${serverHost}:9001" -ForegroundColor Green
