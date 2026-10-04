package safety

import (
	"path/filepath"
	"strings"
)

var blockedPrefixes = []string{
	"/System",
	"/usr",
	"/bin",
	"/sbin",
	"/private/var/db",
	"/Library/Apple",
	"/Library/OSAnalytics",
	"/Library/Updates",
}

// Sensitive user paths — never offer for trash even if a scanner walks nearby.
var blockedHomeSuffixes = []string{
	"/Library/Keychains",
	"/Library/Mail",
	"/Library/Messages",
	"/Library/Calendars",
	"/Library/Accounts",
	"/Library/IdentityServices",
	"/Library/Cookies",
	"/Library/Suggestions",
	"/Library/Shortcuts",
	"/Library/Application Support/AddressBook",
	"/Library/Application Support/CallHistoryDB",
	"/Library/Application Support/com.apple.TCC",
	"/Pictures/Photos Library.photoslibrary",
	"/Music/Music",
	"/.ssh",
	"/.gnupg",
}

// Cache folder names under ~/Library/Caches that hold credentials / sync state.
var blockedCacheNames = map[string]bool{
	"CloudKit":                     true,
	"com.apple.HomeKit":            true,
	"FamilyCircle":                 true,
	"com.apple.findmy":             true,
	"com.apple.Safari.SafeBrowsing": true,
	"com.apple.assistantd":         true,
	"com.apple.ap.adprivacyd":      true,
	"com.apple.containermanagerd":  true,
	"PassKit":                      true,
}

type Opts struct {
	AllowApps bool
}

func Standardize(p string) string {
	if p == "" {
		return ""
	}
	p = filepath.Clean(p)
	if len(p) > 1 && strings.HasSuffix(p, "/") {
		p = strings.TrimRight(p, "/")
	}
	return p
}

func IsAppBundle(path string) bool {
	s := Standardize(path)
	if !(strings.HasSuffix(s, ".app") || strings.Contains(s, ".app/")) {
		return false
	}
	return strings.HasPrefix(s, "/Applications/") || strings.Contains(s, "/Applications/")
}

func IsBlocked(path string, opts Opts) bool {
	s := Standardize(path)
	if s == "/" || s == "/private" {
		return true
	}
	for _, prefix := range blockedPrefixes {
		if s == prefix || strings.HasPrefix(s, prefix+"/") {
			return true
		}
	}
	for _, suf := range blockedHomeSuffixes {
		if strings.HasSuffix(s, suf) || strings.Contains(s, suf+"/") {
			return true
		}
	}
	if base := filepath.Base(s); blockedCacheNames[base] {
		return true
	}
	// Parent cache segment (…/Library/Caches/CloudKit/…)
	parts := strings.Split(s, "/")
	for i := 0; i < len(parts)-1; i++ {
		if parts[i] == "Caches" && blockedCacheNames[parts[i+1]] {
			return true
		}
	}
	if !opts.AllowApps && IsAppBundle(s) {
		return true
	}
	return false
}

func Classify(path, intended string, opts Opts) string {
	if IsBlocked(path, opts) {
		return "blocked"
	}
	return intended
}

func CanTrash(path, safety string, opts Opts) bool {
	return safety != "blocked" && !IsBlocked(path, opts)
}
