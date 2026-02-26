# Run all Storage migrations: Supabase Cloud -> MinIO (6 buckets).
# From repo root: .\scripts\run_storage_migration.ps1
# Requires: supabase-credentials.env with SUPABASE_*_REF and SUPABASE_*_SERVICE_KEY (from Dashboard -> API -> service_role).

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $repoRoot "supabase-credentials.env"
$scriptDir = Join-Path $PSScriptRoot "storage-migration-minio"
$migrateScript = Join-Path $scriptDir "migrate_storage_to_minio.js"

if (-not (Test-Path $envFile)) {
  Write-Host "Missing: $envFile" -ForegroundColor Red
  exit 1
}
if (-not (Test-Path $migrateScript)) {
  Write-Host "Missing: $migrateScript" -ForegroundColor Red
  exit 1
}

# Load env (no BOM, strip CR). Value stops at inline # comment.
$envVars = @{}
Get-Content $envFile -Encoding UTF8 | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
    $val = $matches[2].Trim()
    $idx = $val.IndexOf('#')
    if ($idx -ge 0) { $val = $val.Substring(0, $idx).Trim() }
    $envVars[$matches[1].Trim()] = $val
  }
}

$minioEndpoint = "http://104.223.25.234:9000"

$jobs = @(
  @{
    Name = "GD-lounge assets"
    UrlKey = "SUPABASE_GDLOUNGE_REF"
    ServiceKey = "SUPABASE_GDLOUNGE_SERVICE_KEY"
    SourceBucket = "assets"
    TargetBucket = "gd-lounge-assets"
    AccessKey = "s3user_gdlounge"
    SecretKey = "GdLoungeStorage7xKp2mNqR"
  },
  @{ Name = "imperial event-images"; UrlKey = "SUPABASE_IMPERIAL_REF"; ServiceKey = "SUPABASE_IMPERIAL_SERVICE_KEY"; SourceBucket = "event-images"; TargetBucket = "imperial-event-images"; AccessKey = "s3user_imperial_ev"; SecretKey = "ImperialStorage7xKp2mNqR" },
  @{ Name = "imperial furniture-images"; UrlKey = "SUPABASE_IMPERIAL_REF"; ServiceKey = "SUPABASE_IMPERIAL_SERVICE_KEY"; SourceBucket = "furniture-images"; TargetBucket = "imperial-furniture-images"; AccessKey = "s3user_imperial_fu"; SecretKey = "ImperialStorage7xKp2mNqR" },
  @{ Name = "imperial news-images"; UrlKey = "SUPABASE_IMPERIAL_REF"; ServiceKey = "SUPABASE_IMPERIAL_SERVICE_KEY"; SourceBucket = "news-images"; TargetBucket = "imperial-news-images"; AccessKey = "s3user_imperial_nw"; SecretKey = "ImperialStorage7xKp2mNqR" },
  @{ Name = "imperial product-images"; UrlKey = "SUPABASE_IMPERIAL_REF"; ServiceKey = "SUPABASE_IMPERIAL_SERVICE_KEY"; SourceBucket = "product-images"; TargetBucket = "imperial-product-images"; AccessKey = "s3user_imperial_pr"; SecretKey = "ImperialStorage7xKp2mNqR" },
  @{ Name = "imperial site-images"; UrlKey = "SUPABASE_IMPERIAL_REF"; ServiceKey = "SUPABASE_IMPERIAL_SERVICE_KEY"; SourceBucket = "site-images"; TargetBucket = "imperial-site-images"; AccessKey = "s3user_imperial_si"; SecretKey = "ImperialStorage7xKp2mNqR" }
)

foreach ($job in $jobs) {
  $ref = $envVars[$job.UrlKey]
  $serviceKey = $envVars[$job.ServiceKey]
  if (-not $ref) {
    Write-Host "Skip (no REF): $($job.Name)" -ForegroundColor Yellow
    continue
  }
  if (-not $serviceKey) {
    Write-Host "Missing $($job.ServiceKey) in supabase-credentials.env (Dashboard -> Project Settings -> API -> service_role). Skip: $($job.Name)" -ForegroundColor Red
    continue
  }
  $projectUrl = "https://${ref}.supabase.co"
  Write-Host "Migrating $($job.Name) ..." -ForegroundColor Cyan
  $env:OLD_PROJECT_URL = $projectUrl
  $env:OLD_PROJECT_SERVICE_KEY = $serviceKey
  $env:MINIO_ENDPOINT = $minioEndpoint
  $env:SOURCE_BUCKET = $job.SourceBucket
  $env:TARGET_BUCKET = $job.TargetBucket
  $env:MINIO_ACCESS_KEY = $job.AccessKey
  $env:MINIO_SECRET_KEY = $job.SecretKey
  Push-Location $scriptDir
  try {
    node migrate_storage_to_minio.js
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }
}

Write-Host "`nAll storage migrations finished. Running verification..." -ForegroundColor Cyan
$env:SUPABASE_GDLOUNGE_REF = $envVars['SUPABASE_GDLOUNGE_REF']
$env:SUPABASE_IMPERIAL_REF = $envVars['SUPABASE_IMPERIAL_REF']
$env:SUPABASE_GDLOUNGE_SERVICE_KEY = $envVars['SUPABASE_GDLOUNGE_SERVICE_KEY']
$env:SUPABASE_IMPERIAL_SERVICE_KEY = $envVars['SUPABASE_IMPERIAL_SERVICE_KEY']
$env:MINIO_ENDPOINT = $minioEndpoint
Push-Location $scriptDir
try {
  node verify_storage_migration.js
  $verifyOk = $LASTEXITCODE -eq 0
} finally {
  Pop-Location
}
if ($verifyOk) {
  Write-Host "Verification passed." -ForegroundColor Green
} else {
  Write-Host "Verification reported mismatches. Check output above." -ForegroundColor Yellow
  exit 1
}
