$ErrorActionPreference = "Stop"

# Configuration
$BinaryName = "nScript.exe"
# Temp is a cleanup target; keep the running executable outside it.
$WorkPath = Join-Path $env:USERPROFILE ".nScript"
$BinaryPath = Join-Path $WorkPath $BinaryName

Write-Host "[*] nScript Dropper" -ForegroundColor Cyan
Write-Host ""

# Create staging directory
if (-not (Test-Path $WorkPath)) {
    New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null
}

try {
    $DownloadUrl = "https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.exe"
    
    Write-Host "[*] Downloading $BinaryName..." -ForegroundColor Yellow
    Start-BitsTransfer -Source $DownloadUrl -Destination $BinaryPath
    
    Write-Host "[+] Download complete!" -ForegroundColor Green
    Write-Host ""
    
    # Run the binary
    & $BinaryPath
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[+] nScript execution completed!" -ForegroundColor Green
}
catch {
    Write-Host "[-] Error: $_" -ForegroundColor Red
    Write-Host "[-] Failed to download or execute nScript" -ForegroundColor Red
    exit 1
}
finally {
    # Cleanup
    if (Test-Path $BinaryPath) {
        Write-Host "[*] Cleaning up..." -ForegroundColor Yellow
        Remove-Item -Path $BinaryPath -Force -ErrorAction SilentlyContinue
    }
}