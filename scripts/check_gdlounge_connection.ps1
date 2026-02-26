# Проверка подключения к БД GD-lounge (Supabase Cloud).
# Запуск из корня репозитория: .\scripts\check_gdlounge_connection.ps1
# Опционально: для IPv4 используйте Session pooler — задайте SUPABASE_GDLOUNGE_POOLER_HOST (см. Dashboard → Connect → Session pooler).

$envFile = Join-Path (Join-Path $PSScriptRoot '..') 'supabase-credentials.env'
if (-not (Test-Path $envFile)) {
    Write-Error "Не найден supabase-credentials.env"
}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
}

$ref = $env:SUPABASE_GDLOUNGE_REF
$pwd = $env:SUPABASE_GDLOUNGE_PASSWORD
$poolerHost = $env:SUPABASE_GDLOUNGE_POOLER_HOST
if (-not $ref) { Write-Error "Заполните SUPABASE_GDLOUNGE_REF в supabase-credentials.env" }
if (-not $pwd) { Write-Error "Заполните SUPABASE_GDLOUNGE_PASSWORD в supabase-credentials.env" }

$hostDb = if ($poolerHost) { $poolerHost } else { "db.$ref.supabase.co" }
$env:PGPASSWORD = $pwd
Write-Host "Подключение к $hostDb`:5432/postgres (GD-lounge)..."
try {
    & psql -h $hostDb -p 5432 -U "postgres.$ref" -d postgres -c "SELECT 1 AS test, current_database(), version();"
    if ($LASTEXITCODE -eq 0) { Write-Host "Подключение успешно." } else { Write-Host "Ошибка (код $LASTEXITCODE)." }
} finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
