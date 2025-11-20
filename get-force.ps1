# nScript Installer - FORCE MODE
# Usage: irm https://raw.githubusercontent.com/nyxiereal/nScript/master/install-force.ps1 | iex

$ErrorActionPreference = "Stop"

# Configuration
$RepoOwner = "nyxiereal"
$RepoName = "nScript"
$BinaryName = "nScript-force.exe"
$TempPath = Join-Path $env:TEMP "nScript"
$BinaryPath = Join-Path $TempPath $BinaryName

Write-Host "[*] nScript Installer v2.0.0" -ForegroundColor Cyan
Write-Host "[!] WARNING: FORCE MODE - This will delete ALL files in configured directories!" -ForegroundColor Red
Write-Host "[!] This action cannot be undone!" -ForegroundColor Red
Write-Host ""

# Confirmation prompt
$Confirmation = Read-Host "Type 'YES' in capital letters to continue"
if ($Confirmation -ne "YES") {
    Write-Host "[*] Installation cancelled by user" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "[*] Downloading and running nScript (FORCE MODE)..." -ForegroundColor Yellow
Write-Host ""

# Create temp directory
if (-not (Test-Path $TempPath)) {
    New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
}

try {
    # Download from jsDelivr CDN (dist branch)
    $DownloadUrl = "https://cdn.jsdelivr.net/gh/$RepoOwner/$RepoName@dist/$BinaryName"
    
    Write-Host "[*] Downloading $BinaryName from CDN..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -UseBasicParsing
    
    Write-Host "[+] Download complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[*] Running nScript in FORCE MODE..." -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
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
