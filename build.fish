#!/usr/bin/env fish

# nScript Build Script for Fish Shell
# Builds unified binary for Windows (supports both normal and force modes)

set BINARY_NAME "nScript.exe"

echo "[*] Building nScript"
echo ""

# Check if Go is installed
if not command -v go &> /dev/null
    echo "[-] Go is not installed. Please install Go first."
    exit 1
end

# Download dependencies
echo "[*] Downloading dependencies..."
go mod download
if test $status -ne 0
    echo "[-] Failed to download dependencies"
    exit 1
end
echo "[+] Dependencies downloaded"
echo ""

# Build unified binary
echo "[*] Building $BINARY_NAME (Unified Mode)..."
# Use -trimpath to reduce file paths and -s -w to strip symbol and debug info
env GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o $BINARY_NAME main.go
if test $status -ne 0
    echo "[-] Failed to build $BINARY_NAME"
    exit 1
end
echo "[+] Built $BINARY_NAME"
echo ""

# Show file size
if test -f $BINARY_NAME
    set size (du -h $BINARY_NAME | cut -f1)
    echo "[*] $BINARY_NAME size: $size"
end

echo ""
echo "[+] Build complete!"
echo ""
echo "Usage:"
echo "  Normal Mode:  .\\$BINARY_NAME"
echo "  Force Mode:   .\\$BINARY_NAME --force"
