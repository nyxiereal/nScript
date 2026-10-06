# What nScript deletes

Read this before choosing a mode. nScript resets a user's working environment; it does **not** distinguish unwanted files from schoolwork. Documents, browser accounts, saved games and application data can all be deleted.

For launcher selection, preflight checks and troubleshooting, see [Running nScript](running.md). The authoritative target lists are `New-NsConfig` in [`nScript.ps1`](../nScript.ps1), not the examples on this page.

## Normal versus force

Both modes run all three phases, in order. Neither is a preview, and neither asks for confirmation before deleting files.

| Phase | Normal | Force |
| --- | --- | --- |
| 1. General files and app folders | Deletes eligible files whose **last-modified time** is more than 24 hours old | Deletes eligible files regardless of age |
| 2. Browser/client folders | Skips a configured process's targets when that process is running; otherwise removes them regardless of age | Attempts to stop configured processes; a reported stop failure skips that group's targets. Otherwise removes targets regardless of age, retrying failed removal once |
| 3. Windows cleanup and settings | Clears history/caches/recycle bin, restarts Explorer and applies settings | Same operations as normal |

The 24-hour rule is **not a global safety window**. A new browser profile or recent-item shortcut can be removed by a later phase. Some paths overlap between phases: skipping a running browser in phase 2 does not exempt its overlapping phase-1 targets or prevent policy changes in phase 3.

The age cutoff uses `LastWriteTime`, not download time, creation time or last access. A recently copied file with an old modification time can qualify. Empty subdirectories can be removed regardless of their age; general directory roots are kept. App files and profiles are deleted directly, not moved into the recycle bin.

## What is in scope

### Personal files and existing app targets

The current configuration contains **140 general path entries**, including the original 118 targets and 22 researched additions below. Entries can overlap; this is not a count of unique apps or files.

- Personal folders: Downloads, Documents, Desktop, Videos, Music, Pictures, 3D Objects, Saved Games, Contacts, Links and Favorites.
- Temporary/history data: the profile's `AppData\Local\Temp`, recent items, selected Internet/Office caches, clipboard data, crash dumps and `.cache`.
- Game launchers and game data: Roblox, Y8 Browser, Steam, Epic, Riot/VALORANT, EA/Origin, Battle.net, Ubisoft, GOG, Minecraft/TLauncher, Rockstar, osu!, itch and others.
- Other applications: Discord, Spotify, Slack, Skype, WhatsApp, Telegram, torrent clients, Twitch, TeamViewer, AnyDesk and Godot are already targeted in selected locations.
- Shared locations: selected `%ProgramFiles%`, `%ProgramFiles(x86)%`, `%ProgramData%` paths and the literal `C:\Steam`, `C:\Flashpoint`, `C:\Riot Games` roots.

**Review the list against the school's installed software.** A tool being present in the config does not mean it is unauthorized. In particular, project folders, remote-support apps, Godot projects/data and virtual-machine files may be legitimate. Formats such as `.vdi`, `.vmdk`, `.vbox`, `.sav` and `.zip` are not generally excluded.

### Browser and client data

Phase 2 has **39 paths across 20 process groups**:

- Firefox, Chrome, Edge, Opera, Opera GX, Brave, Vivaldi, AVG Secure Browser and Avast Secure Browser.
- Yandex, Torch, Chromium, Internet Explorer, Maxthon, SeaMonkey, Waterfox, Pale Moon, Slimjet and Cent Browser.
- **OneDrive** (`onedrive.exe`) is also in this list. Force mode can terminate it and target `%USERPROFILE%\AppData\Local\Microsoft\OneDrive`; this is not the user's cloud-document directory, and it is not a registered OneDrive uninstall.

This is broader than clearing caches: Firefox profile directories and `profiles.ini`, Chromium-family user-data directories, and some Opera installation directories are targeted. Expect loss of local sessions, cookies, saved credentials, extensions and unsynced browser data. Browser sync may repopulate some data later; nScript does not disable sign-in or sync.

Only the configured process groups get the phase-2 running-process check. Adding a game launcher to the general list does **not** make nScript stop it first. Locked files can therefore remain.

Process matching is by name, with **no account/session filter**. Another user's running browser can cause normal-mode targets to be skipped. With sufficient permissions, force mode can stop other users' matching browsers/OneDrive; Explorer and Start Menu process operations in phase 3 have the same cross-session risk in either mode.

### Windows changes in both modes

Phase 3 attempts to:

- Stop `StartMenuExperienceHost`, remove selected Start Menu database/TileDataLayer files, and clear matching CloudStore tile entries. Older Windows 10 builds also get legacy TileDataLayer/cache cleanup.
- Restart Windows Explorer. The desktop/taskbar may disappear briefly; this is not restricted to force mode.
- Clear Recent Items, automatic/custom jump-list destinations, thumbnail/icon caches, and Explorer `RecentDocs`, `TypedPaths`, `RunMRU`, `UserAssist` and common Open/Save dialog history.
- Enable Windows/app dark mode.
- Apply the Firefox and Chrome policies below.
- Empty the recycle bin through Windows, without a confirmation prompt or a configured drive filter.

These are best-effort operations, not a guarantee that every Windows version will have the same Start Menu layout afterward.

### Persistent browser policies

These writes use the current account's `HKCU`, including when a browser was left running in normal mode:

| Browser | Changes |
| --- | --- |
| Firefox | Force-install uBlock Origin; lock DuckDuckGo homepage/startup; set DuckDuckGo default search; suppress first-run/update pages and default-browser checking; block `about:config` and the browser's Set As Desktop Background command |
| Chrome | Force-install uBlock Origin Lite; set DuckDuckGo homepage/startup/search; show Home button; suppress promotions and uBOL onboarding; disable new-tab custom backgrounds; create a First Run sentinel if absent |

Existing unrelated forced extensions are preserved, but the listed settings are intentionally replaced, including Chrome's startup URL list. Machine/organization policies can take precedence. Extensions need Internet access on a subsequent browser launch. Restart browsers and inspect `about:policies` or `chrome://policy` to verify the effective policy. Firefox default-search policy requires Firefox 139+ or ESR 60+; Chrome promotion suppression requires Chrome 128+.

Deleting the downloaded script does not undo these policies. They do not set a global Windows wallpaper lock.

## What is preserved, and where that protection applies

### General-file exclusions

Phase 1 preserves `.iso` and `.lnk` files, case-insensitively, **even in force mode**, unless their filename contains one of these substrings:

```text
roblox, y8 browser, y8-browser, y8browser, paradox,
opera, discord, osu, steam, epic games
```

The exception is a filename substring check, not a publisher or file-content check. For example, `Steam backup.iso` can be deleted; `lesson.iso` is excluded. In normal mode, exception files still have to pass the age cutoff.

These extension exclusions **do not apply to phase-2 or phase-3 tree removal**. A `.lnk` in Recent Items, for example, can still be deleted. Do not use an excluded extension as a general backup strategy.

### Protected paths

File-tree traversal preserves directories whose names start with `GT Works3` or `GX Works3`, case-insensitively, including their descendants. `GX Works3 backup` qualifies; an unrelated project directory does not. Reparse points such as junctions/symlinks are skipped or rejected, including when an ancestor is a reparse point.

The path guard also refuses drive roots and the following critical subtrees:

```text
C:\Windows\System32
C:\Windows\SysWOW64
C:\Program Files\Windows NT
C:\Program Files (x86)\Windows NT
```

That is not a blanket exemption for every path under Windows or Program Files. Invalid, relative, device-style and short-name paths may be rejected rather than cleaned. Do not weaken the guard to force a run through an unexpected path.

**Recycle-bin emptying is a separate native Windows operation.** It does not inspect recycled items against the script's extension or protected-directory rules. A previously deleted protected project is not safe merely because it had a protected name.

## Recovery and leftovers

### Registry backups are limited

Before deleting a selected registry key, nScript exports it to a unique `.reg` file under:

```text
%USERPROFILE%\.nScript\registry-backups
```

If export fails or produces an empty file, that key is not deleted. Other cleanup operations can still proceed; this is not a transaction or rollback of earlier phases.

The directory survives launcher cleanup. The printed backup location does not guarantee a backup was created: absent keys need no export, and errors are reported as warnings.

These exports cover **keys selected for deletion**, not deleted files, browser profiles, the recycle bin, or prior values of dark-mode/browser-policy settings that were overwritten. There is no built-in restore command. Inspect a relevant `.reg` file before importing it into the original account; its `HKEY_CURRENT_USER` entries apply to whichever account imports it. Do not bulk-import unrelated backups.

### An app can still appear installed

Deleting app files/data is not a registered uninstall. nScript does not generally execute vendor uninstallers, unregister Store packages, remove services/drivers, find custom game libraries, or stop every targeted application. Newer files in normal mode, excluded shortcuts, locked files and protected directories can remain. Empty general target roots can remain too.

Use the school's approved uninstall/deployment process when the goal is complete software removal. A zero exit code is not proof of removal: individual cleanup failures produce warnings and the script can still finish successfully. See [troubleshooting](running.md#when-something-goes-wrong).

## Researched additions: exact defaults and evidence

This section records the **22 additions**, not the complete 140-entry general list. Sources establish documented defaults, not what is installed on a particular computer.

Path shorthand used below:

- `Profile` = `%USERPROFILE%`
- `Local` = `%USERPROFILE%\AppData\Local`
- `Roaming` = `%USERPROFILE%\AppData\Roaming`

Those two AppData paths are constructed from the profile, matching the existing general config. They are **not dynamically replaced by relocated `%LOCALAPPDATA%` or `%APPDATA%` values**. Custom/portable locations and other accounts are not discovered. The Windows-specific phase does use the corresponding environment variables for its own paths.

| App | Added paths | What they contain / limitation | Primary evidence |
| --- | --- | --- | --- |
| Bloxstrap | `Local\Bloxstrap` | Default install/data; custom locations and QA builds differ | [Installer][blox-installer], [build name][blox-name], [LocalAppData definition][blox-paths] |
| Fishstrap | `Local\Fishstrap` | Default install/data; custom locations and QA builds differ | [Installer][fish-installer], [build name][fish-name] |
| Prism Launcher | `Local\Programs\PrismLauncher`; `Roaming\PrismLauncher` | Installer and data defaults; portable/custom directories differ | [Installer][prism-installer], [installer name][prism-name], [data locations][prism-data] |
| Modrinth App | `Roaming\ModrinthApp` | Default app data; no guessed install root or pre-0.8.0 `com.modrinth.theseus` target | [Storage guide][modrinth] |
| Lunar Client | `Local\Programs\lunarclient`; `Profile\.lunarclient` | Launcher and client data, including account/settings data | [Launcher location][lunar-install], [client settings location][lunar-data] |
| Vencord | `Roaming\Vencord` | Discord mod data; environment overrides not followed | [Path construction][vencord], [Electron path semantics][electron], [Discord base path][discord] |
| Vesktop | `Roaming\Vesktop` | Nonportable client data; portable `Data` and overrides differ | [Path construction][vesktop-paths], [product name][vesktop-name], [Electron path semantics][electron] |
| BetterDiscord | `Roaming\BetterDiscord` | Mod data beside the standard Discord data folder | [Path construction][betterdiscord], [Electron path semantics][electron], [Discord base path][discord] |
| Discord | `Roaming\Discord` | Standard-client data; supplements the existing Local install target | [Installer troubleshooting][discord] |
| CurseForge | `Roaming\CurseForge` | Standalone app data; game mods/content can remain elsewhere | [Uninstall guide][curseforge] |
| Medal | `Local\Medal`; `Local\Programs\Medal`; `Roaming\Medal` | Install locations and settings/local clip-library metadata; arbitrary capture folders are not scanned | [Clean-install guide][medal], [clip backup guide][medal-backup] |
| Playnite | `Roaming\Playnite` | Installed-version library/settings/extensions; no portable/install-root guess | [Official FAQ][playnite] |
| osu!(lazer) | `Local\osulazer`; `Roaming\osu` | Install and beatmap/skin/replay storage; distinct from the existing stable `Local\osu!` target | [Executable location][osu-install], [file storage][osu-data] |
| Plutonium | `Local\Plutonium` | Launcher/mod files; separate game-install directories not scanned | [Uninstall guide][plutonium] |
| NoxPlayer | `Local\Nox` | **Legacy configuration evidence:** the vendor's 2021 Android-5-era guide, not a verified modern full-install location | [Error-1025 guide][nox] |
| BlueStacks 5 | `%ProgramFiles%\BlueStacks_nxt`; `%ProgramData%\BlueStacks_nxt` | Application files and default games/settings location; data can be relocated; services/drivers are not uninstalled | [Vendor install-location guide][bluestacks] |

No paths were guessed for Discord PTB/Canary, LDPlayer 9 or modern Nox install roots. The old WeMod/Wand support URL returned 404 during verification. No new shared Razer/Overwolf/VirtualBox parents or VPN/security/network-tool targets were added. Portable apps can still be hit by an existing broad target, such as Downloads, even though their custom locations are not discovered.

## Maintaining the target list

1. Edit `$paths` in `New-NsConfig` for a general target. Its prefixes are `H` = user profile, `D` = ProgramData, `P` = ProgramFiles, `X` = ProgramFiles(x86), `C` = literal `C:\`. For example, `H|AppData\Local\Bloxstrap` is a config entry, not a shell command.
2. Verify the exact app-specific default with vendor documentation or upstream installer/source code. Record whether it is an install directory, data directory or legacy path. Never add a shared parent just to catch several apps.
3. Remember that `$browserRows` has different semantics: age-independent deletion and a process-stop attempt in force mode. Do not use it as a second general-app list.
4. Update the explicit additions/count assertions in [`test-nscript.ps1`](../test-nscript.ps1). Its hash protects the original 118-entry prefix; appending targets should not require changing that baseline hash. Keep the PowerShell file's UTF-8 BOM for Windows PowerShell 5.1 and its non-ASCII path.
5. Run only the [safe validation checks](running.md#safe-validation-not-a-cleanup-run) on a development host. Actual cleanup validation belongs on an authorized disposable Windows account/machine with recoverable test data, never on this development machine.

Source inspection and passing safe checks do not establish live deployment or successful runtime cleanup on Windows.

[blox-installer]: https://github.com/bloxstraplabs/bloxstrap/blob/02db76006741f039b79ac7547b8054d7f3ccfc05/Bloxstrap/Installer.cs#L22
[blox-name]: https://github.com/bloxstraplabs/bloxstrap/blob/02db76006741f039b79ac7547b8054d7f3ccfc05/Bloxstrap/App.xaml.cs#L15-L21
[blox-paths]: https://github.com/bloxstraplabs/bloxstrap/blob/02db76006741f039b79ac7547b8054d7f3ccfc05/Bloxstrap/Paths.cs#L9
[fish-installer]: https://github.com/fishstrap/fishstrap/blob/988db40e3e259489f95e4c7ec40f8dbf5685f309/Bloxstrap/Installer.cs#L23
[fish-name]: https://github.com/fishstrap/fishstrap/blob/988db40e3e259489f95e4c7ec40f8dbf5685f309/Bloxstrap/App.xaml.cs#L15-L21
[prism-installer]: https://github.com/PrismLauncher/PrismLauncher/blob/7de6e963c258827971640ba8b41c95659a0ba962/program_info/win_install.nsi.in#L11-L12
[prism-name]: https://github.com/PrismLauncher/PrismLauncher/blob/7de6e963c258827971640ba8b41c95659a0ba962/program_info/CMakeLists.txt#L11-L12
[prism-data]: https://prismlauncher.org/wiki/getting-started/data-location/
[modrinth]: https://support.modrinth.com/en/articles/8797641-modrinth-app-storage-folder-location
[lunar-install]: https://support.lunarclient.com/solutions/no-lunar-client-shortcut
[lunar-data]: https://support.lunarclient.com/solutions/external-software-interfering-with-lunar-client
[vencord]: https://github.com/Vendicated/Vencord/blob/3374b8a9d8f6b051c64204917360293aad7f5d75/src/main/utils/constants.ts#L22-L31
[electron]: https://www.electronjs.org/docs/latest/api/app#appgetpathname
[discord]: https://support.discord.com/hc/en-us/articles/209099387--Windows-Installer-Errors
[vesktop-paths]: https://github.com/Vencord/Vesktop/blob/a02035be2083e09666ed250bd977325c35f5be95/src/main/constants.ts#L13-L30
[vesktop-name]: https://github.com/Vencord/Vesktop/blob/a02035be2083e09666ed250bd977325c35f5be95/package.json#L67-L68
[betterdiscord]: https://github.com/BetterDiscord/BetterDiscord/blob/9fc106e8e53e51589374c05cfb03b35f4149d0a2/src/electron/main/modules/betterdiscord.ts#L14-L20
[curseforge]: https://support.curseforge.com/support/solutions/articles/9000240272-uninstalling-curseforge-standalone
[medal]: https://support.medal.tv/support/solutions/articles/48000922105-how-to-purge-medal-for-a-clean-installation
[medal-backup]: https://support.medal.tv/support/solutions/articles/48001227747
[playnite]: https://api.playnite.link/docs/manual/gettingStarted/helpAndTroubleshooting/faq.html
[osu-install]: https://osu.ppy.sh/wiki/en/osu%21_tournament_client
[osu-data]: https://osu.ppy.sh/wiki/en/Client/Release_stream/Lazer/File_storage
[plutonium]: https://plutonium.pw/en/docs/uninstall/
[nox]: https://www.bignox.com/blog/how-to-resolve-error-code-1025-of-noxplayer/
[bluestacks]: https://support.bluestacks.com/hc/en-us/articles/360062369231-How-to-install-BlueStacks-5-at-a-custom-location-on-your-PC
