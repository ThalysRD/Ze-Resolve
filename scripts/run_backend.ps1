param(
    [string]$BindAddress = '127.0.0.1',
    [ValidateRange(1, 65535)][int]$Port = 8000,
    [switch]$Reload,
    [switch]$Https,
    [ValidateSet('server', 'seed', 'docs', 'upgrade', 'tls')][string]$Task = 'server'
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
if ($Https -and $Task -eq 'server') {
    $tlsPath = Join-Path $backendPath 'secrets\tls'
    $certificate = Join-Path $tlsPath 'server.crt'
    $privateKey = Join-Path $tlsPath 'server.key'
    if (-not ((Test-Path -LiteralPath $certificate) -and (Test-Path -LiteralPath $privateKey))) {
        throw 'Certificado TLS ausente. Gere com: .\scripts\run_backend.ps1 -Task tls'
    }
    if (-not $PSBoundParameters.ContainsKey('Port')) { $Port = 8443; $serverArguments[6] = '8443' }
    $serverArguments += @('--ssl-certfile', $certificate, '--ssl-keyfile', $privateKey)
    $env:REQUIRE_HTTPS = 'true'
}
if ($Task -eq 'seed') { $serverArguments = @('-m', 'app.seed') }
if ($Task -eq 'docs') { $serverArguments = @('-m', 'app.export_docs') }
if ($Task -eq 'upgrade') { $serverArguments = @('-m', 'app.migrate') }
if ($Task -eq 'tls') { $serverArguments = @('-m', 'app.tls_setup') }
Push-Location -LiteralPath $backendPath
try {
    if ($Task -eq 'server') { $scheme = if ($Https) { 'https' } else { 'http' }; Write-Host "Iniciando API em ${scheme}://${BindAddress}:$Port." }
    & $pythonPath @serverArguments
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
