param([int]$Port = 2045, [int]$Cores = 8)
$ErrorActionPreference = 'Stop'
$sensorBase = Split-Path -Parent $PSScriptRoot
$sensorConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'COMSOL\config_newrun.json') -Raw | ConvertFrom-Json
$comsolBase = Split-Path -Parent $sensorConfig.comsol.mli_path
$serverExe = Join-Path $comsolBase 'bin\win64\comsolmphserver.exe'
if (-not (Test-Path -LiteralPath $serverExe)) { throw "Missing server executable: $serverExe" }
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw "Port $Port is already in use. Reuse the existing server or choose another port." }
$serverLogs = Join-Path $sensorBase 'Data\Runs\server_logs'
New-Item -ItemType Directory -Path $serverLogs -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$proc = Start-Process -FilePath $serverExe -ArgumentList "-port $Port -np $Cores -login never -silent -multi on" -WindowStyle Hidden -RedirectStandardOutput (Join-Path $serverLogs "server_${Port}_${stamp}.log") -RedirectStandardError (Join-Path $serverLogs "server_${Port}_${stamp}.err.log") -PassThru
Write-Output "Server starting: PID=$($proc.Id), port=$Port. Logs: $serverLogs"
