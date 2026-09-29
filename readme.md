# nScript

A high-performance Go-based system cleanup tool for Windows 10/11 with concurrent operations.

## Features
- removes old garbage files
- cleans temporary files
- removes browser profiles
- removes apps that should not be there

`get-vbox.ps1` (served at `/v` for existing deployments) runs force cleanup as the signed-in Windows user, then requests UAC once to install Inkscape, GIMP 3, VS Code, Python 3.14, Notepad++, Orwell Dev-C++, Temurin 25 JDK (includes `javac`), PyCharm Community, Code::Blocks with MinGW, and IntelliJ IDEA Community via WinGet. App Installer/WinGet must be available to both the signed-in and elevated accounts. The droppers stage `nScript.exe` in `%USERPROFILE%\.nScript` so force cleanup cannot delete the running executable from Temp; they remove it afterward. Cleanup may leave admin-protected files behind; installer scope varies by package. Run `test-get-vbox.ps1` with PowerShell to check syntax and ordering.
