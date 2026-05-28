# avito-ads-launch-wizard.ps1 — открывает ОТДЕЛЬНОЕ окно PowerShell с интерактивным
# мастером настройки. AI вызывает этот скрипт — у пользователя открывается окно,
# где он вводит client_id, client_secret, accountID. AI client_secret не видит.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Wizard    = Join-Path $ScriptDir 'avito-ads-oauth-setup.ps1'

if (-not (Test-Path $Wizard)) {
    Write-Host "❌ Не найден $Wizard"
    exit 1
}

Start-Process powershell.exe -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $Wizard
)
Write-Host "✅ Открыл новое окно PowerShell с мастером Avito Реклама. Перейди в новое окно."
