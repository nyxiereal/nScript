# nScript

PowerShell 5.1 system cleanup for Windows 10/11. **Review `nScript.ps1` before running either mode; cleanup cannot be undone.**

Normal mode removes general files older than 24 hours and leaves running browsers alone. Closed-browser profiles, Windows history/caches, and the recycle bin are cleared regardless of age. Force mode also removes newer general files and stops browsers before deleting their profiles. General file cleanup preserves `.iso` and `.lnk` files except the configured app-name exceptions. Both modes preserve directories starting with `GT Works3` or `GX Works3` (case-insensitive), including their contents, and never traverse junctions/symlinks.

Cleanup is best-effort: inaccessible files are reported and skipped. Registry keys are exported to restorable `.reg` files in `%USERPROFILE%\.nScript\registry-backups` before deletion; failed exports prevent deletion. Those backups survive cleanup. Fatal startup/download errors fail the launch, while individual cleanup warnings do not prevent `/v` from installing apps.

## Operator notes

- [What nScript deletes](docs/cleanup-targets.md): phase-by-phase behavior, exclusions, registry recovery limits, exact added targets and their sources.
- [Running nScript](docs/running.md): launcher selection, account/permission checks, `/v` installs, safe validation and troubleshooting.

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

All launchers download the **real** `nScript.ps1` from `https://clean.meowery.eu/nScript.ps1`, stage it under `%USERPROFILE%\.nScript` outside the Temp cleanup target, and run it in a child `powershell.exe -NoProfile -File` process (with `-Force` for force routes). `/`, `/f`, `/v`, `/c`, and `/fc` remain PowerShell-text routes; direct `.ps1` URLs serve plain UTF-8 text. `/c` and `/fc` download the corresponding batch launcher and run it through `cmd.exe`; direct `.cmd` URLs download batch files. The old `/nScript.exe` artifact is retired rather than serving script text under an executable name. Use `/nScript.ps1` for the actual source artifact. Vercel serves the tracked files on `master` directly, without a build or `dist` branch.

`/v` downloads a pinned portable x64 WinGet bundle before force cleanup under the signed-in user's account, checks its SHA-256 and runs `winget --version`. After cleanup it requests UAC **once** to install Inkscape, GIMP 3, VS Code, Python 3.14, Notepad++, Orwell Dev-C++, Temurin 25 JDK, PyCharm Community, Code::Blocks with MinGW, and IntelliJ IDEA Community. The elevated process verifies a private copy of the archive before using it. No App Installer registration is required; `winget-portable.zip` is tracked on `master` and served at `https://clean.meowery.eu/winget-portable.zip`. The pinned 16,311,484-byte SHA-256 `88536696deaa13ea7441df74a62dd782f8cac75e46a23407b63b7ce8d39989cc` archive was originally bundled from Microsoft's winget-cli v1.29.380 release. CI checks its hash; it does not build or publish the bundle. Installer scope varies by package; cleanup may leave admin-protected files behind.

After browser cleanup, nScript applies policies for the signed-in Windows user (HKCU). Firefox force-installs uBlock Origin; Chrome force-installs uBlock Origin Lite. Both use DuckDuckGo as their homepage, startup page, and default search, and suppress first-run prompts. Firefox blocks `about:config` and its "Set As Desktop Background" command; Chrome disables new-tab background customization. Existing desktop wallpaper settings are unchanged. Extensions download on the next browser launch and need Internet access. Restart browsers to apply policies and check `about:policies` or `chrome://policy` for errors. These settings persist and replace listed HKCU values while preserving unrelated policies and forced extensions; machine/organization policies can override them. Firefox default search requires Firefox 139+ or ESR 60+; Chrome promotion suppression requires Chrome 128+.

## Validate without running cleanup

`pwsh -NoProfile -File ./test-get-vbox.ps1` checks the launchers, routes, committed bundle and validation workflow statically. `pwsh -NoProfile -File ./test-nscript.ps1` checks the core script's syntax and pure path/configuration logic; `pwsh -NoProfile -File ./test-nscript-windows.ps1` checks integration and pure Firefox JSON merging. None invokes the cleaner, filesystem deletion, process termination, or registry changes. On pushes to `master`, pull requests and manual dispatch, CI runs all three checks on Ubuntu PowerShell 7 and Windows PowerShell 5.1, plus a Windows WinGet search smoke test without installs. `make` and `./build.fish` run safe checks only; neither CI nor Vercel builds or publishes an artifact. Local checks do not prove Windows 5.1 compatibility or production deployment; verify both after publishing.
