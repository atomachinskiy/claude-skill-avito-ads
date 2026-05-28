# avito-ads-oauth-setup.ps1 — интерактивный мастер настройки для Windows.
# Запускается в отдельном окне PowerShell через avito-ads-launch-wizard.ps1,
# чтобы client_secret не попал в transcript AI.

$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillDir   = Split-Path -Parent $ScriptDir
$SecretsDir = Join-Path $HOME '.claude\secrets'
$EnvFile    = Join-Path $SkillDir 'config\.env'
$TokensFile = Join-Path $SecretsDir 'avito-ads-tokens'

if (-not (Test-Path $SecretsDir)) { New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null }
if (-not (Test-Path (Split-Path -Parent $EnvFile))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $EnvFile) -Force | Out-Null
}

Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '  Avito Реклама API — настройка' -ForegroundColor Cyan
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Где взять ключи:'
Write-Host '  1. https://ads.avito.ru/cabinet'
Write-Host '  2. Аккаунт → API → «Создать ключ» (нужна роль Администратор)'
Write-Host '  3. Скопируй client_id и client_secret'
Write-Host '  4. Запомни accountID'
Write-Host ''

# Прочитать существующий .env, если он есть и заполнен
$UseExisting = $false
if (Test-Path $EnvFile) {
    $envContent = Get-Content $EnvFile -Raw
    if ($envContent -match 'AVITO_ADS_CLIENT_ID=.+' -and $envContent -match 'AVITO_ADS_CLIENT_SECRET=.+') {
        Write-Host "[✓] Найден заполненный $EnvFile" -ForegroundColor Green
        $ans = Read-Host 'Использовать существующие ключи? [Y/n]'
        if ($ans -notmatch '^[nN]') { $UseExisting = $true }
    }
}

$Mode = 'sandbox'
if (-not $UseExisting) {
    $ClientId     = Read-Host 'client_id'
    if (-not $ClientId) { Write-Error 'client_id пустой'; exit 1 }

    $SecureSecret = Read-Host 'client_secret (не отображается)' -AsSecureString
    $ClientSecret = [System.Net.NetworkCredential]::new('', $SecureSecret).Password
    if (-not $ClientSecret) { Write-Error 'client_secret пустой'; exit 1 }

    $AccountId = Read-Host 'accountID'
    if (-not $AccountId) { Write-Error 'accountID пустой'; exit 1 }

    Write-Host ''
    Write-Host 'Режим работы:'
    Write-Host '  [s] sandbox (https://api.avito.ru/ads-sandbox/) — рекомендую для первых тестов'
    Write-Host '  [p] prod    (https://api.avito.ru/ads/)        — боевые запросы, тратят API-баллы'
    $modeAns = Read-Host 'Режим [s/p] (default s)'
    if ($modeAns -match '^[pP]') { $Mode = 'prod' }

    $envBody = @"
# Avito Реклама API credentials
# Сгенерировано $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
AVITO_ADS_CLIENT_ID=$ClientId
AVITO_ADS_CLIENT_SECRET=$ClientSecret
AVITO_ADS_ACCOUNT_ID=$AccountId
AVITO_ADS_MODE=$Mode
"@
    Set-Content -Path $EnvFile -Value $envBody -Encoding UTF8
    Write-Host "[✓] Сохранил в $EnvFile" -ForegroundColor Green
} else {
    $envLines = Get-Content $EnvFile
    foreach ($line in $envLines) {
        if ($line -match '^AVITO_ADS_CLIENT_ID=(.+)$')     { $ClientId     = $Matches[1] }
        if ($line -match '^AVITO_ADS_CLIENT_SECRET=(.+)$') { $ClientSecret = $Matches[1] }
        if ($line -match '^AVITO_ADS_ACCOUNT_ID=(.+)$')    { $AccountId    = $Matches[1] }
        if ($line -match '^AVITO_ADS_MODE=(.+)$')          { $Mode         = $Matches[1] }
    }
}

if ($Mode -eq 'prod') {
    $ApiBase = 'https://api.avito.ru/ads'
} else {
    $ApiBase = 'https://api.avito.ru/ads-sandbox'
}

Write-Host ''
Write-Host 'Получаю access_token...' -ForegroundColor Yellow
try {
    $tokenResp = Invoke-RestMethod -Method POST -Uri 'https://api.avito.ru/token' `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{
            grant_type    = 'client_credentials'
            client_id     = $ClientId
            client_secret = $ClientSecret
        }
} catch {
    Write-Error "Не удалось получить токен: $($_.Exception.Message)"
    exit 1
}

$Access  = $tokenResp.access_token
$Expires = if ($tokenResp.expires_in) { $tokenResp.expires_in } else { 86400 }

if (-not $Access) { Write-Error 'Не получили access_token'; exit 1 }

$Now       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$ExpiresAt = (Get-Date).ToUniversalTime().AddSeconds([int]$Expires).ToString("yyyy-MM-ddTHH:mm:ssZ")

$tokenBody = @"
# Avito Реклама access token (issued $Now)
# expires in $Expires seconds (≈ 24h)
AVITO_ADS_ACCESS_TOKEN=$Access
AVITO_ADS_TOKEN_EXPIRES_AT=$ExpiresAt
AVITO_ADS_TOKEN_MODE=$Mode
"@
Set-Content -Path $TokensFile -Value $tokenBody -Encoding UTF8
Write-Host "[✓] Токен получен и сохранён в $TokensFile" -ForegroundColor Green

Write-Host ''
Write-Host 'Проверяю аккаунт...' -ForegroundColor Yellow
try {
    $accResp = Invoke-RestMethod -Method GET -Uri "$ApiBase/v1/account/$AccountId" `
        -Headers @{ Authorization = "Bearer $Access"; Accept = 'application/json' }
    $balResp = Invoke-RestMethod -Method GET -Uri "$ApiBase/v1/account/$AccountId/balance" `
        -Headers @{ Authorization = "Bearer $Access"; Accept = 'application/json' }

    $shortName = $accResp.account.shortName
    $inn       = $accResp.account.inn
    $balance   = $balResp.balance
    $bonus     = $balResp.bonusBalance
} catch {
    Write-Host "⚠ Проверка не удалась: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Green
Write-Host '  ✅ Avito Реклама API настроен и работает' -ForegroundColor Green
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Green
Write-Host ''
if ($shortName) { Write-Host "  Аккаунт:        $shortName (ИНН $inn)" }
Write-Host "  accountID:      $AccountId"
Write-Host "  Режим:          $Mode  ($ApiBase)"
if ($balance -ne $null) { Write-Host "  Баланс:         $balance ₽" }
if ($bonus   -ne $null) { Write-Host "  Бонусный:       $bonus ₽" }
Write-Host ''
Write-Host "  Конфиг:    $EnvFile"
Write-Host "  Токены:    $TokensFile"
Write-Host ''
Write-Host 'Дальше в чате с Клодом можно спрашивать:'
Write-Host '  • «Покажи активные кампании в Avito Реклама»'
Write-Host '  • «Сделай отчёт по тратам за месяц»'
Write-Host '  • «Сравни CPM/CTR кампаний за неделю»'
Write-Host ''
Read-Host 'Готово. Нажми Enter чтобы закрыть это окно'
