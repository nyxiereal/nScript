.PHONY: all build build-force clean test deps help

# Variables
BINARY_NAME=nScript.exe
FORCE_BINARY_NAME=nScript-force.exe
GO=go
GOFLAGS=-ldflags="-s -w"
GOOS=windows
GOARCH=amd64

all: deps build build-force

help:
	@echo "nScript Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Download dependencies and build all binaries"
	@echo "  deps         - Download Go dependencies"
	@echo "  build        - Build normal mode binary"
	@echo "  build-force  - Build force mode binary"
	@echo "  clean        - Remove built binaries"
	@echo "  test         - Run tests"
	@echo "  help         - Show this help message"

deps:
	@echo "[*] Downloading dependencies..."
	$(GO) mod download
	@echo "[+] Dependencies downloaded"

build:
	@echo "[*] Building $(BINARY_NAME)..."
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=0 $(GO) build $(GOFLAGS) -o $(BINARY_NAME) main.go
	@echo "[+] Built $(BINARY_NAME)"

build-force:
	@echo "[*] Building $(FORCE_BINARY_NAME)..."
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=0 $(GO) build $(GOFLAGS) -o $(FORCE_BINARY_NAME) force.go
	@echo "[+] Built $(FORCE_BINARY_NAME)"

clean:
	@echo "[*] Cleaning..."
	rm -f $(BINARY_NAME) $(FORCE_BINARY_NAME)
	@echo "[+] Cleaned"

test:
	@echo "[*] Running tests..."
	$(GO) test -v ./...
	@echo "[+] Tests complete"
