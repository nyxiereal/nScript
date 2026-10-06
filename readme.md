# nScript

A high-performance Go-based system cleanup tool for Windows 10/11 with concurrent operations.

## Features
- removes old garbage files
- cleans temporary files
- removes browser profiles
- removes apps that should not be there
- configures Firefox and Chrome with ad blocking and DuckDuckGo

After browser cleanup, nScript applies policies for the signed-in Windows user (HKCU). Firefox force-installs uBlock Origin; Chrome force-installs uBlock Origin Lite. Both use DuckDuckGo as their homepage, startup page, and default search, and suppress first-run prompts. Firefox blocks `about:config` and its "Set As Desktop Background" command; Chrome disables new-tab background customization. Existing Windows desktop wallpaper settings are not changed.

Extensions download on the next browser launch and require Internet access. Restart browsers to apply policies and inspect `about:policies` (Firefox) or `chrome://policy` (Chrome) for errors. This persistently replaces the listed HKCU settings (including Chrome's startup URL list), while preserving unrelated policies and forced extensions. Higher-priority machine/organization policies can override these per-user settings; this does not configure other Windows accounts. Firefox's default-search policy requires Firefox 139+ or ESR 60+; Chrome's promotion-suppression policy requires Chrome 128+. Normal mode leaves running browsers open, so restart them afterward.

`get-vbox.ps1` (served at `/v` for existing deployments) downloads a portable x64 WinGet bundle before force cleanup as the signed-in Windows user, then requests UAC once to install Inkscape, GIMP 3, VS Code, Python 3.14, Notepad++, Orwell Dev-C++, Temurin 25 JDK (includes `javac`), PyCharm Community, Code::Blocks with MinGW, and IntelliJ IDEA Community. No App Installer registration is required; the release workflow packages WinGet from Microsoft's pinned v1.29.380 release and publishes `winget-portable.zip` alongside the script. The droppers stage `nScript.exe` in `%USERPROFILE%\.nScript` so force cleanup cannot delete the running executable from Temp; `/v` removes both the cleaner and portable WinGet afterward. Cleanup may leave admin-protected files behind; installer scope varies by package. Run `test-get-vbox.ps1` with PowerShell to check syntax and ordering.

`get.cmd` and `get-force.cmd` are the same droppers for machines where PowerShell is blocked or restricted. They use only Microsoft-signed LOLBins from the [LOLBAS project](https://lolbas-project.github.io/): `curl.exe -fsSL` with a `certutil -urlcache -split -f` fallback for the download, and `cmd.exe` for the launch. They stage `nScript.exe` in `%USERPROFILE%\.nScript`, reject downloads smaller than 100 KB, and delete the executable afterward.

`/c` and `/fc` serve PowerShell bootstrappers around those batch files, so every route works with the usual one-liner, for example `powershell -NoProfile -Command "irm https://clean.meowery.eu/fc | iex"`. On a host without PowerShell, a Pico/Ducky types a single cmd line instead, fetching the batch file directly:

```
cmd /c mkdir "%USERPROFILE%\.nScript" 2>nul& certutil -urlcache -split -f https://clean.meowery.eu/get-force.cmd "%USERPROFILE%\.nScript\get-force.cmd" >nul& call "%USERPROFILE%\.nScript\get-force.cmd"& del "%USERPROFILE%\.nScript\get-force.cmd"
```

LOLBins only remove the PowerShell dependency; they do not bypass application control. Smart App Control validates the downloaded `nScript.exe` itself and still blocks it while it is unsigned, whichever signed binary launches it. Those machines need a signed build, or SAC turned off by an administrator.
