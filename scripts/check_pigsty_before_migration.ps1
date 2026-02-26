# Check Pigsty server state before Supabase migration (GD-lounge, imperial).
# Load credentials from supabase-credentials.env (do not commit that file).
# Usage: from repo root, .\scripts\check_pigsty_before_migration.ps1

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot "..\supabase-credentials.env"
if (-not (Test-Path $envFile)) {
    Write-Host "Missing supabase-credentials.env (copy from supabase-credentials.env.example and fill)." -ForegroundColor Red
    exit 1
}

# Load env (avoid echoing secrets)
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $k = $matches[1].Trim()
        $v = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($k, $v, "Process")
    }
}

$host = $env:PIGSTY_HOST
if (-not $host) { Write-Host "PIGSTY_HOST not set in supabase-credentials.env"; exit 1 }

Write-Host "`n=== 1. Server reachability (SSH) ===" -ForegroundColor Cyan
try {
    $sshTest = ssh -o ConnectTimeout=5 -o BatchMode=yes "st@$host" "echo OK" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "SSH failed (BatchMode). Check key or use: ssh st@$host" -ForegroundColor Yellow
    } else {
        Write-Host "SSH OK: $sshTest"
    }
} catch {
    Write-Host "SSH error: $_" -ForegroundColor Yellow
}

Write-Host "`n=== 2. On server: PostgreSQL, MinIO, PgBouncer (no password sent over SSH) ===" -ForegroundColor Cyan
$cmd = "echo '--- 5432 ---'; (ss -tlnp 2>/dev/null || true) | grep ':5432' || true; echo '--- 6432 ---'; (ss -tlnp 2>/dev/null || true) | grep ':6432' || true; echo '--- MinIO ---'; curl -s -o /dev/null -w 'MinIO: %{http_code}' http://127.0.0.1:9000/minio/health/live 2>/dev/null || echo 'MinIO unreachable'; echo ''"
ssh "st@$host" $cmd 2>&1

Write-Host "`n=== 3. Databases gdloungedb / imperialdb (on server) ===" -ForegroundColor Cyan
$scriptPath = Join-Path $PSScriptRoot "remote_check_db.sh"
if (Test-Path $scriptPath) {
    Get-Content $scriptPath -Raw | ForEach-Object { $_ -replace "`r`n", "`n" } | ssh "st@$host" "bash -s" 2>&1
    Write-Host "If gdloungedb/imperialdb are missing, create them: on server run ./pgsql.yml -l pg-meta (pigsty.yml already has pg_databases)." -ForegroundColor Yellow
} else {
    Write-Host "Run on server: sudo -u postgres psql -d postgres -t -c ""\l"" to list DBs." -ForegroundColor Yellow
}

Write-Host "`nDone. Fix any failures before running migration (export/restore)." -ForegroundColor Cyan
