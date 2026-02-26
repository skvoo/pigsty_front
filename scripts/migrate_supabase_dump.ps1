# Экспорт двух БД Supabase (GD-lounge, imperial) и восстановление на Pigsty (gdloungedb, imperialdb).
# Запуск из корня репозитория: .\scripts\migrate_supabase_dump.ps1
# Требуется: заполненный supabase-credentials.env (REF и пароли для обоих проектов, PIGSTY_POSTGRES_PASSWORD).

param(
    [switch]$DumpOnly,   # только экспорт из Supabase
    [switch]$RestoreOnly  # только восстановление на Pigsty (файлы backup_*.dump должны быть в текущей папке)
)

$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot '..' 'supabase-credentials.env'
if (-not (Test-Path $envFile)) {
    Write-Error "Не найден файл supabase-credentials.env (ожидается в корне репозитория). Скопируйте из supabase-credentials.env.example и заполните."
}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $val = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($key, $val, 'Process')
    }
}

$refGd = $env:SUPABASE_GDLOUNGE_REF
$pwdGd = $env:SUPABASE_GDLOUNGE_PASSWORD
$refImp = $env:SUPABASE_IMPERIAL_REF
$pwdImp = $env:SUPABASE_IMPERIAL_PASSWORD
$pigstyHost = $env:PIGSTY_HOST
if (-not $pigstyHost) { $pigstyHost = '104.223.25.234' }
$pigstyPwd = $env:PIGSTY_POSTGRES_PASSWORD

if (-not $RestoreOnly) {
    if (-not $refGd -or -not $pwdGd) { Write-Error "Заполните SUPABASE_GDLOUNGE_REF и SUPABASE_GDLOUNGE_PASSWORD в supabase-credentials.env" }
    if (-not $refImp -or -not $pwdImp) { Write-Error "Заполните SUPABASE_IMPERIAL_REF и SUPABASE_IMPERIAL_PASSWORD в supabase-credentials.env" }

    Write-Host "Экспорт GD-lounge..."
    $hostGd = $env:SUPABASE_GDLOUNGE_POOLER_HOST
    if (-not $hostGd) { $hostGd = "db.${refGd}.supabase.co" }
    $urlGd = "postgresql://postgres.${refGd}:${pwdGd}@${hostGd}:5432/postgres"
    & pg_dump $urlGd --no-owner --no-privileges --exclude-schema=graphql_public --exclude-schema=extensions --format custom --file backup_gdlounge.dump
    if ($LASTEXITCODE -ne 0) { throw "pg_dump GD-lounge failed" }

    Write-Host "Экспорт imperial..."
    $hostImp = $env:SUPABASE_IMPERIAL_POOLER_HOST
    if (-not $hostImp) { $hostImp = "db.${refImp}.supabase.co" }
    $urlImp = "postgresql://postgres.${refImp}:${pwdImp}@${hostImp}:5432/postgres"
    & pg_dump $urlImp --no-owner --no-privileges --exclude-schema=graphql_public --exclude-schema=extensions --format custom --file backup_imperial.dump
    if ($LASTEXITCODE -ne 0) { throw "pg_dump imperial failed" }

    Write-Host "Экспорт завершён: backup_gdlounge.dump, backup_imperial.dump"
    if ($DumpOnly) { exit 0 }
}

if (-not $pigstyPwd) { Write-Error "Заполните PIGSTY_POSTGRES_PASSWORD в supabase-credentials.env для восстановления на Pigsty" }
if (-not (Test-Path backup_gdlounge.dump)) { Write-Error "Файл backup_gdlounge.dump не найден (запустите без -RestoreOnly)" }
if (-not (Test-Path backup_imperial.dump)) { Write-Error "Файл backup_imperial.dump не найден (запустите без -RestoreOnly)" }

$env:PGPASSWORD = $pigstyPwd
Write-Host "Восстановление в gdloungedb..."
& pg_restore -h $pigstyHost -p 5432 -U postgres -d gdloungedb --no-owner --no-privileges backup_gdlounge.dump
# pg_restore возвращает 1 при предупреждениях (например, роли) — не прерываем
Write-Host "Восстановление в imperialdb..."
& pg_restore -h $pigstyHost -p 5432 -U postgres -d imperialdb --no-owner --no-privileges backup_imperial.dump
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

Write-Host "Готово. Проверьте БД на Pigsty (расширения, RLS, при необходимости перенесите Storage)."
