# nScript

A high-performance Go-based system cleanup tool for Windows 10/11 with concurrent operations.

## Features
- removes old garbage files
- cleans temporary files
- removes browser profiles
- removes apps that should not be there

`get-vbox.ps1` (served at `/v`) runs force cleanup without admin, then downloads the latest stable VirtualBox Windows installer from Oracle and requests UAC only to launch it. Cleanup may leave admin-protected files behind. Run `test-get-vbox.ps1` with PowerShell to check the script's syntax and execution order.
