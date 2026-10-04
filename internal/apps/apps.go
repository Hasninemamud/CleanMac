package apps

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"

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

// sizeOf measures paths including .app bundles (AllowApps).
func sizeOf(p string) int64 {
	info, err := os.Lstat(p)
	if err != nil {
		return 0
	}
	if info.IsDir() {
		// ponytail: 20k entry cap — enough for real .app sizes without multi-second walks.
		return fsutil.DirectorySizeOpts(p, 20_000, safety.Opts{AllowApps: true})
	}
	return info.Size()
}

func readBundleID(appPath string) string {
	plist := filepath.Join(appPath, "Contents/Info.plist")
	// plutil handles binary + XML plists; one short process beats defaults+full path quirks.
	cmd := exec.Command("/usr/bin/plutil", "-extract", "CFBundleIdentifier", "raw", "-o", "-", plist)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func listInstalled() []installedApp {
	dirs := []string{"/Applications", filepath.Join(fsutil.HomeDir(), "Applications")}
	var apps []installedApp
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)

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
			wg.Add(1)
			go func(appPath, name string) {
				defer wg.Done()
				sem <- struct{}{}
				bid := readBundleID(appPath)
				<-sem
				tokens := []string{normalizeToken(name)}
				if t := normalizeToken(bid); t != "" {
					tokens = append(tokens, t)
				}
				mu.Lock()
				apps = append(apps, installedApp{Path: appPath, Name: name, BundleID: bid, Tokens: tokens})
				mu.Unlock()
			}(appPath, name)
		}
	}
	wg.Wait()
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
	Apps    []AppResult    `json:"apps"`
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

	type pending struct {
		full, name, root string
		isDir            bool
		matches          []installedApp
	}
	var jobs []pending

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
			typ := ent.Type()
			if typ&os.ModeSymlink != 0 {
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
			if len(matches) > 1 {
				continue // ambiguous — skip rather than attach to wrong app
			}
			seen[full] = true
			jobs = append(jobs, pending{full: full, name: ent.Name(), root: root, isDir: ent.IsDir(), matches: matches})
		}
	}

	type sized struct {
		item    jsonout.Item
		appPath string // empty = orphan
	}
	sizedCh := make([]sized, len(jobs))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)
	for i, job := range jobs {
		wg.Add(1)
		go func(i int, job pending) {
			defer wg.Done()
			sem <- struct{}{}
			byteSize := sizeOf(job.full)
			<-sem
			if byteSize <= 0 {
				return
			}
			intended := "review"
			explanation := "Leftover in " + job.root
			if strings.Contains(job.root, "Caches") {
				intended = "safe"
				explanation = "App cache · " + job.root
			} else if strings.Contains(job.root, "Logs") {
				intended = "safe"
				explanation = "App logs · " + job.root
			}
			item := jsonout.Item{
				Path: job.full, Name: job.name, ByteSize: byteSize,
				Safety: safety.Classify(job.full, intended, safety.Opts{}),
				Kind: "leftover", Root: job.root, Explanation: explanation,
				IsDirectory: job.isDir, Category: categoryForRoot(job.root),
			}
			if len(job.matches) == 1 {
				sizedCh[i] = sized{item: item, appPath: job.matches[0].Path}
			} else {
				item.Orphan = true
				if strings.Contains(job.root, "Caches") {
					item.Explanation = "Orphaned app cache · " + job.root
				} else {
					item.Explanation = "Orphaned leftover · " + job.root
				}
				sizedCh[i] = sized{item: item}
			}
		}(i, job)
	}
	wg.Wait()

	for _, s := range sizedCh {
		if s.item.Path == "" {
			continue
		}
		if s.appPath != "" {
			byApp[s.appPath] = append(byApp[s.appPath], s.item)
		} else {
			orphans = append(orphans, s.item)
		}
	}

	results := make([]AppResult, len(installed))
	var appWG sync.WaitGroup
	for i, app := range installed {
		appWG.Add(1)
		go func(i int, app installedApp) {
			defer appWG.Done()
			sem <- struct{}{}
			appBytes := sizeOf(app.Path)
			<-sem
			leftovers := byApp[app.Path]
			var leftoverBytes int64
			for _, l := range leftovers {
				leftoverBytes += l.ByteSize
			}
			results[i] = AppResult{
				Path: app.Path, Name: app.Name, BundleID: app.BundleID,
				// byteSize = app bundle only (original data). Leftovers stay separate.
				ByteSize: appBytes, AppBytes: appBytes,
				LeftoverBytes: leftoverBytes, Leftovers: leftovers,
				Safety: "review", Explanation: "Installed application",
			}
		}(i, app)
	}
	appWG.Wait()

	sort.Slice(results, func(i, j int) bool {
		if results[i].AppBytes != results[j].AppBytes {
			return results[i].AppBytes > results[j].AppBytes
		}
		return results[i].Name < results[j].Name
	})
	sort.Slice(orphans, func(i, j int) bool { return orphans[i].ByteSize > orphans[j].ByteSize })
	return ScanResult{Apps: results, Orphans: orphans}
}
