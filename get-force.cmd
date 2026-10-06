@echo off
setlocal DisableDelayedExpansion
rem Run a fresh PowerShell 5.1 script outside Temp; never execute a partial or stale download.
echo [!] FORCE MODE: deletes user files and browser profiles without asking.
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=Join-Path (Join-Path $env:USERPROFILE '.nScript') ([guid]::NewGuid().ToString('N')); [void](New-Item -ItemType Directory -Path $r -Force); try { $p=Join-Path $r 'nScript.ps1'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.ps1' -OutFile $p -UseBasicParsing; if ((Get-Item -LiteralPath $p).Length -eq 0) { throw 'Empty download' }; & powershell.exe -NoProfile -File $p -Force; exit $LASTEXITCODE } finally { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }"
exit /b %ERRORLEVEL%
