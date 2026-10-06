$ErrorActionPreference = 'Stop'

# Delivered at /fc so `irm https://clean.meowery.eu/fc | iex` works. The batch file
# owns the download logic; this shim only fetches it and runs it through cmd.exe.
$WorkPath = Join-Path $env:USERPROFILE '.nScript'
$CmdPath = Join-Path $WorkPath 'get-force.cmd'
New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null

try {
    Invoke-WebRequest -Uri 'https://clean.meowery.eu/get-force.cmd' -OutFile $CmdPath -UseBasicParsing
    & cmd.exe /c $CmdPath
}
finally {
    Remove-Item -LiteralPath $CmdPath -Force -ErrorAction SilentlyContinue
}
