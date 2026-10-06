# nScript

PowerShell 5.1 system cleanup for Windows 10/11. Normal mode removes old garbage and temporary files, cleans browser profiles, removes unwanted apps, and configures Firefox and Chrome with DuckDuckGo and ad blocking. Force mode deletes files and browser profiles without asking. **Review `nScript.ps1` before running either mode; cleanup cannot be undone.**

## Run

From Windows PowerShell:

```powershell
irm https://clean.meowery.eu/ | iex       # normal
irm https://clean.meowery.eu/f | iex      # force
irm https://clean.meowery.eu/v | iex      # force + portable WinGet apps
irm https://clean.meowery.eu/c | iex      # normal via get.cmd
irm https://clean.meowery.eu/fc | iex     # force via get-force.cmd
```

Or download `get.cmd` / `get-force.cmd` and run them from `cmd.exe`. Both batch launchers require Windows PowerShell 5.1. They do not bypass execution policy, application control, or UAC. If script execution is blocked, use a policy permitted by your administrator; these launchers do not pass `-ExecutionPolicy Bypass`.

All launchers download the **real** `nScript.ps1` artifact from `https://raw.githubusercontent.com/nyxiereal/nScript/dist/nScript.ps1`, stage it under `%USERPROFILE%\.nScript` outside the Temp cleanup target, and run it in a child `powershell.exe -NoProfile -File` process (with `-Force` for force routes). `/`, `/f`, `/v`, `/c`, and `/fc` remain PowerShell-text routes; direct `.ps1` URLs serve plain UTF-8 text. `/c` and `/fc` download the corresponding batch launcher and run it through `cmd.exe`. The old `/nScript.exe` route is retired: there was no live executable asset to serve. Use `/nScript.ps1` for the actual source artifact.

`/v` downloads a pinned portable x64 WinGet bundle before force cleanup under the signed-in user's account, checks its SHA-256 and runs `winget --version`. After cleanup it requests UAC **once** to install Inkscape, GIMP 3, VS Code, Python 3.14, Notepad++, Orwell Dev-C++, Temurin 25 JDK, PyCharm Community, Code::Blocks with MinGW, and IntelliJ IDEA Community. The elevated process verifies a private copy of the archive before using it. No App Installer registration is required; the release workflow bundles WinGet from Microsoft's pinned v1.29.380 release and checks the archive hash. Installer scope varies by package; cleanup may leave admin-protected files behind.

After browser cleanup, nScript applies policies for the signed-in Windows user (HKCU). Firefox force-installs uBlock Origin; Chrome force-installs uBlock Origin Lite. Both use DuckDuckGo as their homepage, startup page, and default search, and suppress first-run prompts. Firefox blocks `about:config` and its "Set As Desktop Background" command; Chrome disables new-tab background customization. Existing desktop wallpaper settings are unchanged. Extensions download on the next browser launch and need Internet access. Restart browsers to apply policies and check `about:policies` or `chrome://policy` for errors. These settings persist and replace listed HKCU values while preserving unrelated policies and forced extensions; machine/organization policies can override them. Firefox default search requires Firefox 139+ or ESR 60+; Chrome promotion suppression requires Chrome 128+.

## Validate without running cleanup

`pwsh -NoProfile -File ./test-get-vbox.ps1` checks the launchers, routes and release workflow statically. `pwsh -NoProfile -File ./test-nscript.ps1` checks the core script. The workflow also runs both plus `test-nscript-windows.ps1` under **Windows PowerShell 5.1** before publishing. `make` and `./build.fish` run safe checks only; there is no Go or EXE build.
