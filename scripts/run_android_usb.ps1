param([string]$DeviceId, [switch]$Http)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
$adbPath = if ($adbCommand) { $adbCommand.Source } else {
    Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
}
if (-not (Test-Path -LiteralPath $adbPath)) {
    throw 'ADB não encontrado. Instale as ferramentas do Android SDK e adicione platform-tools ao PATH.'
}

if (-not $DeviceId) {
    $devices = @(& $adbPath devices | ForEach-Object {
        if ($_ -match '^(\S+)\s+device$') { $Matches[1] }
    })
    if ($devices.Count -ne 1) {
        throw 'Conecte um único celular com depuração USB autorizada, ou informe -DeviceId.'
    }
    $DeviceId = $devices[0]
}

# Padrão: HTTPS com a AC do Zé Resolve fixada no app. -Http mantém o modo antigo, sem criptografia.
$port = if ($Http) { 8000 } else { 8443 }
$defines = @("--dart-define=API_BASE_URL=$(if ($Http) { 'http' } else { 'https' })://127.0.0.1:$port")
if (-not $Http) {
    $caPath = Join-Path $projectRoot 'backend\secrets\tls\ca.crt'
    if (-not (Test-Path -LiteralPath $caPath)) { throw 'AC ausente. Gere com: .\scripts\run_backend.ps1 -Task tls' }
    $defines += "--dart-define=API_CA_CERT_B64=$([Convert]::ToBase64String([IO.File]::ReadAllBytes($caPath)))"
}

& $adbPath -s $DeviceId reverse tcp:$port tcp:$port
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível encaminhar a porta da API pelo USB.' }

Push-Location -LiteralPath $projectRoot
try {
    & flutter run -d $DeviceId @defines
    if ($LASTEXITCODE -ne 0) { throw 'O Flutter não conseguiu iniciar o aplicativo.' }
} finally { Pop-Location }
