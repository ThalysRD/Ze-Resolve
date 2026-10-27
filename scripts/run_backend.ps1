param(
    [string]$BindAddress = '127.0.0.1',
    [ValidateRange(1, 65535)][int]$Port = 8000,
    [switch]$Reload,
    [ValidateSet('server', 'seed', 'docs', 'upgrade', 'test')][string]$Task = 'server'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $projectRoot 'backend'
$environmentFile = Join-Path $backendPath '.env'
$pythonPath = Join-Path $backendPath '.venv\Scripts\python.exe'

if (Test-Path -LiteralPath $environmentFile) {
    $lineNumber = 0
    foreach ($entry in Get-Content -LiteralPath $environmentFile -Encoding UTF8) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($entry) -or $entry.TrimStart().StartsWith('#')) { continue }
        if ($entry -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
            throw "Configuração inválida na linha $lineNumber de backend/.env."
        }
        $settingName = $Matches[1]
        $settingValue = $Matches[2]
        if ($settingName -notmatch '^(DATABASE_URL|CORS_ORIGINS|GOOGLE_APPLICATION_CREDENTIALS|FCM_USE_ADC|DATA_ENCRYPTION_KEY|DATA_ENCRYPTION_KEY_FILE|APP_ENV|TRUSTED_HOSTS|REQUIRE_HTTPS|BOOKING_HOLD_MINUTES|SMTP_[A-Z_]+|APP_CONTACT_EMAIL)$') {
            throw "Variável não suportada na linha $lineNumber de backend/.env."
        }
        if ($settingValue.Length -ge 2 -and (
            ($settingValue.StartsWith('"') -and $settingValue.EndsWith('"')) -or
            ($settingValue.StartsWith("'") -and $settingValue.EndsWith("'")))) {
            $settingValue = $settingValue.Substring(1, $settingValue.Length - 2)
        }
        [Environment]::SetEnvironmentVariable($settingName, $settingValue, 'Process')
    }
}

if (-not (Test-Path -LiteralPath $pythonPath)) {
    throw 'Ambiente Python ausente. Crie backend/.venv e instale backend/requirements.txt antes de iniciar.'
}

$serverArguments = @('-m', 'uvicorn', 'app.main:app', '--host', $BindAddress, '--port', "$Port", '--no-access-log', '--limit-concurrency', '128', '--ws-max-size', '16384')
if ($Reload) { $serverArguments += '--reload' }
if ($Task -eq 'seed') { $serverArguments = @('-m', 'app.seed') }
if ($Task -eq 'docs') { $serverArguments = @('-m', 'app.export_docs') }
if ($Task -eq 'upgrade') { $serverArguments = @('-m', 'app.migrate') }
if ($Task -eq 'test') {
    $serverArguments = @('-m', 'app.run_tests')
}
Push-Location -LiteralPath $backendPath
try {
    if ($Task -eq 'server') { Write-Host "Iniciando API em http://${BindAddress}:$Port." }
    & $pythonPath @serverArguments
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
