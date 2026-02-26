# Копирует учётные данные на сервер (пароли в кавычках для bash), затем запускает pull_supabase_to_server.sh
# Запуск из корня репо: .\scripts\run_pull_supabase_from_local.ps1
# Требуется: supabase-credentials.env в корне, SSH доступ к st@104.223.25.234

$ErrorActionPreference = "Stop"
$envFile = Join-Path (Split-Path $PSScriptRoot -Parent) "supabase-credentials.env"
$serverEnv = "supabase-credentials.env"
$serverUser = "st"
$serverHost = "104.223.25.234"

if (-not (Test-Path $envFile)) {
  Write-Host "Файл не найден: $envFile" -ForegroundColor Red
  exit 1
}

# Читаем переменные и формируем файл для сервера: значения с $ и кавычками оборачиваем в одинарные кавычки для bash
$lines = Get-Content $envFile -Encoding UTF8 | Where-Object { $_ -match '^\s*([^#][^=]+)=(.*)$' }
$sb = [System.Text.StringBuilder]::new()
foreach ($line in $lines) {
  if ($line -match '^\s*([^#][^=]+)=(.*)$') {
    $key = $matches[1].Trim()
    $val = $matches[2].Trim()
    if ($val -match '\$|"|''|\s') {
      $val = "'" + ($val -replace "'", "'\''") + "'"
    }
    [void]$sb.AppendLine("$key=$val")
  }
}
$content = $sb.ToString() -replace "`r`n", "`n"

# Записываем во временный файл (UTF-8 без BOM, LF только — иначе bash/парсер обрезает значения) и копируем на сервер
$tmp = [System.IO.Path]::GetTempFileName()
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($tmp, $content, $utf8NoBom)
try {
  scp $tmp "${serverUser}@${serverHost}:~/${serverEnv}"
} finally {
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

Write-Host "Credentials copied to server. Running migration..." -ForegroundColor Cyan
$scriptPath = Join-Path $PSScriptRoot "pull_supabase_to_server.sh"
$scriptContent = (Get-Content $scriptPath -Raw -Encoding UTF8) -replace "`r`n", "`n"
$tmpScript = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpScript, $scriptContent, [System.Text.UTF8Encoding]::new($false))
try {
  scp $tmpScript "${serverUser}@${serverHost}:~/pull_supabase_to_server.sh"
} finally {
  Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue
}
ssh "${serverUser}@${serverHost}" "chmod +x ~/pull_supabase_to_server.sh && bash ~/pull_supabase_to_server.sh"
