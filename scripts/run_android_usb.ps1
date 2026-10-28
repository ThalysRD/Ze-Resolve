param([string]$DeviceId)

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

& $adbPath -s $DeviceId reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível encaminhar a porta da API pelo USB.' }

Push-Location -LiteralPath $projectRoot
try {
    & flutter run -d $DeviceId --dart-define=API_BASE_URL=http://127.0.0.1:8000
    if ($LASTEXITCODE -ne 0) { throw 'O Flutter não conseguiu iniciar o aplicativo.' }
} finally { Pop-Location }
