$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Delivered at /c for irm | iex; cmd.exe runs the actual batch launcher.
$RunPath = Join-Path (Join-Path $env:USERPROFILE '.nScript') ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $RunPath -Force | Out-Null
$PreviousCmd = $env:NSCRIPT_CMD
try {
    $CmdPath = Join-Path $RunPath 'get.cmd'
    Invoke-WebRequest -Uri 'https://clean.meowery.eu/get.cmd' -OutFile $CmdPath -UseBasicParsing
    if ((Get-Item -LiteralPath $CmdPath).Length -eq 0) { throw 'Batch download is empty.' }
    # Pass the path through the environment so cmd does not re-expand %, ! or other path characters.
    $env:NSCRIPT_CMD = $CmdPath
    & cmd.exe /d /v:off /s /c '""%NSCRIPT_CMD%""'
    if ($LASTEXITCODE -ne 0) { throw "get.cmd exited with code $LASTEXITCODE" }
}
finally {
    if ($null -eq $PreviousCmd) { Remove-Item Env:NSCRIPT_CMD -ErrorAction SilentlyContinue }
    else { $env:NSCRIPT_CMD = $PreviousCmd }
    Remove-Item -LiteralPath $RunPath -Recurse -Force -ErrorAction SilentlyContinue
}
