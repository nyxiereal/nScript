package config

import (
	"os"
	"path/filepath"
	"time"
)

const (
	Version             = "2.0.7"
	OnlyRemoveOlderThan = 24 * time.Hour
	MaxConcurrentOps    = 500
	UpdateInterval      = 50 * time.Millisecond
	MaxBatchSize        = 1000 // For streaming file processing
)

type Config struct {
	UserDirectories    []string
	BrowserInformation map[string][]string
	ExcludedExtensions []string
}

// GetConfig returns the hardcoded configuration as requested
func GetConfig() *Config {
	userHome := os.Getenv("USERPROFILE")
	programData := os.Getenv("ProgramData")
	programFilesX86 := os.Getenv("ProgramFiles(x86)")

	return &Config{
		UserDirectories:    buildUserDirectories(userHome, programData, programFilesX86),
		BrowserInformation: buildBrowserInfo(userHome),
		ExcludedExtensions: []string{
			".iso", ".vdi", ".sav", ".vbox", ".vbox-prev",
			".vmdk", ".vhd", ".hdd", ".nvram", ".ova",
			".ovf", ".vbox-extpack", ".vhdx", ".qcow2", ".img", ".lnk",
		},
	}
}

func buildUserDirectories(userHome, programData, programFilesX86 string) []string {
	return []string{
		filepath.Join(userHome, "Downloads"),
		filepath.Join(userHome, "Documents"),
		filepath.Join(userHome, "Desktop"),
		filepath.Join(userHome, "Videos"),
		filepath.Join(userHome, "Music"),
		filepath.Join(userHome, "Pictures"),
		filepath.Join(userHome, "3D Objects"),
		filepath.Join(userHome, "Saved Games"),
		filepath.Join(userHome, "Contacts"),
		filepath.Join(userHome, "Links"),
		filepath.Join(userHome, "Favorites"),
		filepath.Join(userHome, "AppData", "Local", "Temp"),
		filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Recent"),
		filepath.Join(userHome, "AppData", "Local", "Low", "Microsoft", "Internet Explorer"),
		filepath.Join(userHome, "AppData", "Local", "Microsoft", "Windows", "INetCache"),
		filepath.Join(userHome, "AppData", "Local", "Microsoft", "Windows", "INetCookies"),
		filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Office", "Recent"),
		filepath.Join(userHome, "AppData", "Local", "Microsoft", "Windows", "Clipboard"),
		filepath.Join(userHome, ".cache"),
		filepath.Join(userHome, "AppData", "Local", "Roblox"),
		filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Roblox"),
		filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Discord Inc"),
		filepath.Join(userHome, "AppData", "Local", "Discord"),
		filepath.Join(programData, "Microsoft", "Windows", "Start Menu", "Programs", "Epic Games Launcher.lnk"),
		filepath.Join(programFilesX86, "Epic Games"),
		filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "osu!.lnk"),
		filepath.Join(userHome, "AppData", "Local", "osu!"),
		filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Paradox Interactive"),
		filepath.Join(userHome, "AppData", "Local", "Programs", "Paradox Interactive"),
		filepath.Join(userHome, "MicrosoftEdgeBackups"),
		filepath.Join(userHome, "AppData", "Roaming", "Godot"),
		filepath.Join(userHome, "AppData", "Roaming", ".tlauncher"),
		filepath.Join(userHome, "AppData", "Roaming", ".minecraft"),
		filepath.Join("C:", "Steam"),
		filepath.Join("C:", "Flashpoint"),
		filepath.Join("C:", "Program Files", "Epic Games"),
		filepath.Join("C:", "ProgramData", "Riot Games"),
		filepath.Join(userHome, "AppData", "Local", "Riot Games"),
		filepath.Join(userHome, "AppData", "Roaming", "Riot Games"),
		filepath.Join("C:", "Riot Games"),
		filepath.Join(userHome, "AppData", "Local", "Programs", "Riot Games"),
		filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Riot Games"),
		filepath.Join(userHome, "AppData", "Local", "EA Games"),
		filepath.Join(userHome, "AppData", "Roaming", "Origin"),
		filepath.Join(userHome, "AppData", "Local", "Origin"),
		filepath.Join("C:", "Program Files", "Origin"),
		filepath.Join("C:", "Program Files (x86)", "Origin"),
		filepath.Join(userHome, "AppData", "Local", "Battle.net"),
		filepath.Join(userHome, "AppData", "Roaming", "Battle.net"),
		filepath.Join("C:", "Program Files (x86)", "Battle.net"),
		filepath.Join(userHome, "AppData", "Local", "Blizzard Entertainment"),
		filepath.Join(userHome, "AppData", "Roaming", "Blizzard Entertainment"),
		filepath.Join(userHome, "AppData", "Local", "Steam"),
		filepath.Join(userHome, "AppData", "Roaming", "Steam"),
		filepath.Join(userHome, "AppData", "Local", "Programs", "Steam"),
		filepath.Join("C:", "Program Files (x86)", "Steam"),
		filepath.Join(userHome, "AppData", "Local", "Ubisoft Game Launcher"),
		filepath.Join("C:", "Program Files (x86)", "Ubisoft"),
		filepath.Join(userHome, "AppData", "Roaming", "GOG.com"),
		filepath.Join(userHome, "AppData", "Local", "GOG.com"),
		filepath.Join("C:", "Program Files (x86)", "GOG Galaxy"),
		filepath.Join(userHome, "AppData", "Roaming", "Minecraft Launcher"),
		filepath.Join(userHome, "AppData", "Local", "Packages", "Microsoft.MinecraftUWP_8wekyb3d8bbwe"),
		filepath.Join(userHome, "AppData", "Local", "CrashDumps"),
		filepath.Join(userHome, "AppData", "Local", "FortniteGame"),
		filepath.Join(userHome, "AppData", "Local", "UnrealEngine"),
		filepath.Join(userHome, "AppData", "Local", "VALORANT"),
		filepath.Join(userHome, "AppData", "Local", "Rockstar Games"),
		filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Rockstar Games"),
		filepath.Join("C:", "Program Files", "Rockstar Games"),
		filepath.Join(userHome, "AppData", "Local", "2K"),
		filepath.Join(userHome, "AppData", "Roaming", "2K"),
		filepath.Join(userHome, "AppData", "Local", "ROBLOX Corporation"),
		filepath.Join(userHome, "AppData", "Local", "Roblox Studio"),
		filepath.Join(userHome, "AppData", "Local", "Programs", "Roblox"),
		filepath.Join("C:", "Program Files (x86)", "Roblox"),
		filepath.Join(userHome, "AppData", "Local", "Microsoft", "Games"),
		filepath.Join(userHome, "AppData", "Local", "Packages", "Microsoft.GamingApp_8wekyb3d8bbwe"),
		filepath.Join(userHome, "AppData", "Local", "Packages", "Microsoft.XboxApp_8wekyb3d8bbwe"),
		filepath.Join(userHome, "AppData", "Local", "Packages", "Microsoft.XboxGamingOverlay_8wekyb3d8bbwe"),
		filepath.Join(userHome, "AppData", "Local", "SquareEnix"),
		filepath.Join(userHome, "Documents", "My Games"),
		filepath.Join(userHome, "Documents", "EA Games"),
		filepath.Join(userHome, "Documents", "Rockstar Games"),
		filepath.Join(userHome, "Saved Games", "EA"),
		filepath.Join(userHome, "AppData", "Local", "TeamViewer"),
		filepath.Join(userHome, "AppData", "Roaming", "TeamViewer"),
		filepath.Join("C:", "Program Files (x86)", "TeamViewer"),
		filepath.Join(userHome, "AppData", "Local", "AnyDesk"),
		filepath.Join(userHome, "AppData", "Roaming", "AnyDesk"),
		filepath.Join("C:", "Program Files (x86)", "AnyDesk"),
		filepath.Join(userHome, "AppData", "Local", "Spotify"),
		filepath.Join(userHome, "AppData", "Roaming", "Spotify"),
		filepath.Join(userHome, "AppData", "Local", "Programs", "Spotify"),
		filepath.Join(userHome, "AppData", "Local", "slack"),
		filepath.Join(userHome, "AppData", "Roaming", "Slack"),
		filepath.Join(userHome, "AppData", "Local", "Programs", "slack"),
		filepath.Join(userHome, "AppData", "Local", "Skype"),
		filepath.Join(userHome, "AppData", "Roaming", "Skype"),
		filepath.Join(userHome, "AppData", "Local", "Microsoft", "Skype for Desktop"),
		filepath.Join(userHome, "AppData", "Local", "WhatsApp"),
		filepath.Join(userHome, "AppData", "Roaming", "WhatsApp"),
		filepath.Join(userHome, "AppData", "Local", "Telegram Desktop"),
		filepath.Join(userHome, "AppData", "Roaming", "Telegram Desktop"),
		filepath.Join(userHome, "AppData", "Local", "qBittorrent"),
		filepath.Join(userHome, "AppData", "Roaming", "qBittorrent"),
		filepath.Join(userHome, "AppData", "Roaming", "uTorrent"),
		filepath.Join(userHome, "AppData", "Local", "uTorrent"),
		filepath.Join(userHome, "AppData", "Roaming", "BitTorrent"),
		filepath.Join(userHome, "AppData", "Local", "BitTorrent"),
		filepath.Join(userHome, "AppData", "Local", "Twitch"),
		filepath.Join(userHome, "AppData", "Roaming", "Twitch"),
		filepath.Join(userHome, "AppData", "Local", "Programs", "Twitch"),
		filepath.Join(userHome, "AppData", "Local", "itch"),
		filepath.Join(userHome, "AppData", "Roaming", "itch"),
	}
}

func buildBrowserInfo(userHome string) map[string][]string {
	return map[string][]string{
		"firefox.exe": {
			filepath.Join(userHome, "AppData", "Roaming", "Mozilla", "Firefox", "Profiles"),
			filepath.Join(userHome, "AppData", "Local", "Mozilla", "Firefox", "Profiles"),
			filepath.Join(userHome, "AppData", "Roaming", "Mozilla", "Firefox", "profiles.ini"),
		},
		"chrome.exe": {
			filepath.Join(userHome, "AppData", "Local", "Google", "Chrome", "User Data"),
		},
		"msedge.exe": {
			filepath.Join(userHome, "AppData", "Local", "Microsoft", "Edge", "User Data"),
		},
		"opera.exe": {
			filepath.Join(userHome, "AppData", "Roaming", "Opera Software", "Opera Stable"),
			filepath.Join(userHome, "AppData", "Local", "Opera Software", "Opera Stable"),
			filepath.Join(userHome, "AppData", "Roaming", "Opera Software"),
			filepath.Join(userHome, "AppData", "Local", "Opera Software"),
			filepath.Join(userHome, "AppData", "Local", "Programs", "Opera"),
		},
		"opera_gx.exe": {
			filepath.Join(userHome, "AppData", "Roaming", "Opera Software", "Opera GX Stable"),
			filepath.Join(userHome, "AppData", "Local", "Opera Software", "Opera GX Stable"),
			filepath.Join(userHome, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs", "Przeglądarka Opera GX.lnk"),
			filepath.Join(userHome, "AppData", "Local", "Programs", "Opera GX"),
		},
		"brave.exe": {
			filepath.Join(userHome, "AppData", "Local", "BraveSoftware", "Brave-Browser", "User Data"),
			filepath.Join(userHome, "AppData", "Roaming", "BraveSoftware"),
		},
		"vivaldi.exe": {
			filepath.Join(userHome, "AppData", "Local", "Vivaldi", "User Data"),
			filepath.Join(userHome, "AppData", "Roaming", "Vivaldi"),
		},
		"avgsecurebrowser.exe": {
			filepath.Join(userHome, "AppData", "Local", "AVG", "Browser", "User Data"),
			filepath.Join(userHome, "AppData", "Roaming", "AVG", "Browser"),
		},
		"avastsecurebrowser.exe": {
			filepath.Join(userHome, "AppData", "Local", "AVAST Software", "Browser", "User Data"),
			filepath.Join(userHome, "AppData", "Roaming", "AVAST Software", "Browser"),
		},
		"yandex.exe": {
			filepath.Join(userHome, "AppData", "Local", "Yandex", "YandexBrowser", "User Data"),
			filepath.Join(userHome, "AppData", "Roaming", "Yandex"),
		},
		"torch.exe": {
			filepath.Join(userHome, "AppData", "Local", "Torch", "User Data"),
			filepath.Join(userHome, "AppData", "Roaming", "Torch"),
		},
		"chromium.exe": {
			filepath.Join(userHome, "AppData", "Local", "Chromium", "User Data"),
		},
		"iexplore.exe": {
			filepath.Join(userHome, "AppData", "Local", "Microsoft", "Windows", "INetCache"),
			filepath.Join(userHome, "AppData", "Local", "Microsoft", "Windows", "INetCookies"),
			filepath.Join(userHome, "AppData", "Local", "Microsoft", "Internet Explorer"),
		},
		"maxthon.exe": {
			filepath.Join(userHome, "AppData", "Roaming", "Maxthon5"),
			filepath.Join(userHome, "AppData", "Local", "Maxthon5"),
		},
		"seamonkey.exe": {
			filepath.Join(userHome, "AppData", "Roaming", "Mozilla", "SeaMonkey"),
			filepath.Join(userHome, "AppData", "Local", "Mozilla", "SeaMonkey"),
		},
		"waterfox.exe": {
			filepath.Join(userHome, "AppData", "Roaming", "Waterfox"),
			filepath.Join(userHome, "AppData", "Local", "Waterfox"),
		},
		"palemoon.exe": {
			filepath.Join(userHome, "AppData", "Roaming", "Moonchild Productions", "Pale Moon"),
			filepath.Join(userHome, "AppData", "Local", "Moonchild Productions", "Pale Moon"),
		},
		"slimjet.exe": {
			filepath.Join(userHome, "AppData", "Local", "Slimjet", "User Data"),
		},
		"cent.exe": {
			filepath.Join(userHome, "AppData", "Local", "CentBrowser", "User Data"),
		},
		"onedrive.exe": {
			filepath.Join(userHome, "AppData", "Local", "Microsoft", "OneDrive"),
		},
	}
}
