package apps

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/safety"
	"github.com/Hasninemamud/CleanMac/internal/whitelist"
)

var leftoverRoots = []string{
	"Library/Application Support", "Library/Caches", "Library/Preferences",
	"Library/Logs", "Library/Saved Application State", "Library/Containers",
	"Library/Group Containers", "Library/WebKit", "Library/HTTPStorages",
	"Library/Application Scripts", "Library/Cookies",
}

var skipNames = map[string]bool{
	"apple": true, "com.apple": true, "addressbook": true, "icloud": true,
	"cloudkit": true, "callhistorytransactions": true, "knowledge": true,
	"syncservices": true, "mobile documents": true, "containers": true,
	"group containers": true, "caches": true, "preferences": true,
	"logs": true, "google": true,
}

type installedApp struct {
	Path     string
	Name     string
	BundleID string
	Tokens   []string
}

func normalizeToken(s string) string {
	s = strings.ToLower(s)
	s = strings.TrimSuffix(s, ".app")
	re := regexp.MustCompile(`[^a-z0-9]+`)
	return re.ReplaceAllString(s, "")
}

func sizeOf(p string) int64 {
	info, err := os.Lstat(p)
	if err != nil {
		return 0
	}
	if info.IsDir() {
		return fsutil.DirectorySize(p, 80_000)
	}
	return info.Size()
}

func readBundleID(appPath string) string {
	cmd := exec.Command("/usr/bin/defaults", "read", filepath.Join(appPath, "Contents/Info"), "CFBundleIdentifier")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func listInstalled() []installedApp {
	dirs := []string{"/Applications", filepath.Join(fsutil.HomeDir(), "Applications")}
	var apps []installedApp
	for _, appsDir := range dirs {
		if !fsutil.Exists(appsDir) {
			continue
		}
		entries, err := os.ReadDir(appsDir)
		if err != nil {
			continue
		}
		for _, ent := range entries {
			if !ent.IsDir() || !strings.HasSuffix(ent.Name(), ".app") {
				continue
			}
			appPath := filepath.Join(appsDir, ent.Name())
			name := strings.TrimSuffix(ent.Name(), ".app")
			bid := readBundleID(appPath)
			tokens := []string{normalizeToken(name)}
			if t := normalizeToken(bid); t != "" {
				tokens = append(tokens, t)
			}
			apps = append(apps, installedApp{Path: appPath, Name: name, BundleID: bid, Tokens: tokens})
		}
	}
	return apps
}

func entryMatchesApp(entryName string, app installedApp) bool {
	n := strings.ToLower(entryName)
	token := normalizeToken(entryName)
	if token == "" || len(token) < 3 {
		return false
	}
	for _, t := range app.Tokens {
		if t == "" || len(t) < 3 {
			continue
		}
		if token == t || strings.Contains(token, t) || strings.Contains(t, token) {
			return true
		}
	}
	if app.BundleID != "" {
		bid := strings.ToLower(app.BundleID)
		if strings.Contains(n, bid) || strings.HasPrefix(n, bid) {
			return true
		}
	}
	return false
}

func looksLikeAppData(entryName string) bool {
	n := strings.ToLower(entryName)
	token := normalizeToken(entryName)
	if token == "" || len(token) < 4 {
		return false
	}
	if skipNames[token] || skipNames[n] {
		return false
	}
	if strings.HasPrefix(n, "com.apple.") || strings.HasPrefix(n, "apple.") {
		return false
	}
	if n == ".ds_store" {
		return false
	}
	if strings.Contains(n, ".") || strings.Contains(n, " ") {
		return true
	}
	return len(token) >= 5
}

func categoryForRoot(root string) string {
	switch {
	case strings.Contains(root, "Caches"):
		return "cache"
	case strings.Contains(root, "Logs"):
		return "logs"
	case strings.Contains(root, "Preferences"):
		return "preferences"
	default:
		return "leftover"
	}
}

type AppResult struct {
	Path          string         `json:"path"`
	Name          string         `json:"name"`
	BundleID      string         `json:"bundleId,omitempty"`
	ByteSize      int64          `json:"byteSize"`
	AppBytes      int64          `json:"appBytes"`
	LeftoverBytes int64          `json:"leftoverBytes"`
	Leftovers     []jsonout.Item `json:"leftovers"`
	Safety        string         `json:"safety"`
	Explanation   string         `json:"explanation"`
}

type ScanResult struct {
	Apps    []AppResult   `json:"apps"`
	Orphans []jsonout.Item `json:"orphans"`
}

func Scan() ScanResult {
	installed := listInstalled()
	byApp := map[string][]jsonout.Item{}
	for _, a := range installed {
		byApp[a.Path] = nil
	}
	var orphans []jsonout.Item
	seen := map[string]bool{}
	home := fsutil.HomeDir()

	for _, root := range leftoverRoots {
		dir := filepath.Join(home, root)
		if !fsutil.Exists(dir) {
			continue
		}
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, ent := range entries {
			info, err := ent.Info()
			if err != nil || info.Mode()&os.ModeSymlink != 0 {
				continue
			}
			full := filepath.Join(dir, ent.Name())
			if whitelist.Excludes(full) || safety.IsBlocked(full, safety.Opts{}) || seen[full] || !looksLikeAppData(ent.Name()) {
				continue
			}
			var matches []installedApp
			for _, app := range installed {
				if entryMatchesApp(ent.Name(), app) {
					matches = append(matches, app)
				}
			}
			byteSize := sizeOf(full)
			if byteSize <= 0 {
				continue
			}
			seen[full] = true
			intended := "review"
			explanation := "Leftover in " + root
			if strings.Contains(root, "Caches") {
				intended = "safe"
				explanation = "App cache · " + root
			} else if strings.Contains(root, "Logs") {
				intended = "safe"
				explanation = "App logs · " + root
			}
			item := jsonout.Item{
				Path: full, Name: ent.Name(), ByteSize: byteSize,
				Safety: safety.Classify(full, intended, safety.Opts{}),
				Kind: "leftover", Root: root, Explanation: explanation,
				IsDirectory: info.IsDir(),
				Category:    categoryForRoot(root),
			}
			if len(matches) == 1 {
				byApp[matches[0].Path] = append(byApp[matches[0].Path], item)
			} else if len(matches) == 0 {
				item.Orphan = true
				if strings.Contains(root, "Caches") {
					item.Explanation = "Orphaned app cache · " + root
				} else {
					item.Explanation = "Orphaned leftover · " + root
				}
				orphans = append(orphans, item)
			}
		}
	}

	var results []AppResult
	for _, app := range installed {
		leftovers := byApp[app.Path]
		var leftoverBytes int64
		for _, l := range leftovers {
			leftoverBytes += l.ByteSize
		}
		appBytes := fsutil.DirectorySize(app.Path, 60_000)
		results = append(results, AppResult{
			Path: app.Path, Name: app.Name, BundleID: app.BundleID,
			ByteSize: appBytes + leftoverBytes, AppBytes: appBytes,
			LeftoverBytes: leftoverBytes, Leftovers: leftovers,
			Safety: "review", Explanation: "App + Library leftovers",
		})
	}
	sort.Slice(results, func(i, j int) bool {
		if results[i].LeftoverBytes != results[j].LeftoverBytes {
			return results[i].LeftoverBytes > results[j].LeftoverBytes
		}
		return results[i].ByteSize > results[j].ByteSize
	})
	sort.Slice(orphans, func(i, j int) bool { return orphans[i].ByteSize > orphans[j].ByteSize })
	return ScanResult{Apps: results, Orphans: orphans}
}
