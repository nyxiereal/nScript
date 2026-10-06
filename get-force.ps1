$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Temp is a cleanup target. Keep each invocation outside it and never reuse a stale download.
$RunPath = Join-Path (Join-Path $env:USERPROFILE '.nScript') ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $RunPath -Force | Out-Null
try {
    $ScriptPath = Join-Path $RunPath 'nScript.ps1'
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.ps1' -OutFile $ScriptPath -UseBasicParsing
    if ((Get-Item -LiteralPath $ScriptPath).Length -eq 0) { throw 'nScript download is empty.' }
    Write-Host '[!] FORCE MODE: deletes user files and browser profiles without asking.'
    & powershell.exe -NoProfile -File $ScriptPath -Force
    if ($LASTEXITCODE -ne 0) { throw "nScript exited with code $LASTEXITCODE" }
}
finally {
    Remove-Item -LiteralPath $RunPath -Recurse -Force -ErrorAction SilentlyContinue
}
