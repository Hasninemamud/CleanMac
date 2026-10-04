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

// Mole orphan roots (apps.sh): never Containers / Group Containers / Application Scripts.
var orphanRoots = []string{
	"Library/Caches",
	"Library/Logs",
	"Library/Saved Application State",
}

// Extra top-level Library dirs scanned for name/bundle leftovers beyond exact patterns.
var leftoverScanRoots = []string{
	"Library/Application Support",
	"Library/Caches",
	"Library/Containers",
	"Library/Group Containers",
	"Library/Logs",
	"Library/Preferences",
	"Library/Saved Application State",
	"Library/WebKit",
	"Library/HTTPStorages",
	"Library/Application Scripts",
	"Library/Cookies",
	"Library/Autosave Information",
}

var skipNames = map[string]bool{
	"apple": true, "com.apple": true, "addressbook": true, "icloud": true,
	"cloudkit": true, "callhistorytransactions": true, "knowledge": true,
	"syncservices": true, "mobile documents": true, "containers": true,
	"group containers": true, "caches": true, "preferences": true,
	"logs": true, "google": true, "homebrew": true,
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
	s = strings.TrimSuffix(s, ".plist")
	s = strings.TrimSuffix(s, ".savedstate")
	s = strings.TrimSuffix(s, ".binarycookies")
	re := regexp.MustCompile(`[^a-z0-9]+`)
	return re.ReplaceAllString(s, "")
}

func isReverseDNS(bid string) bool {
	if bid == "" || strings.ContainsAny(bid, "*?[/") {
		return false
	}
	parts := strings.Split(bid, ".")
	if len(parts) < 2 {
		return false
	}
	for _, p := range parts {
		if p == "" {
			return false
		}
	}
	return true
}

func sizePath(p string) int64 {
	// Measure even when trash-blocked (Cookies etc.) — Mole still reports those bytes.
	if n, ok := fsutil.DuBytes(p); ok {
		return n
	}
	info, err := os.Lstat(p)
	if err != nil {
		return 0
	}
	if info.IsDir() && strings.HasSuffix(strings.ToLower(p), ".app") {
		return fsutil.PathSizeOpts(p, safety.Opts{AllowApps: true})
	}
	return fsutil.DirectorySizeOpts(p, 100_000, safety.Opts{})
}

func sizeApp(p string) int64 {
	return fsutil.PathSizeOpts(p, safety.Opts{AllowApps: true})
}

func sizeLeftover(p string) int64 {
	return sizePath(p)
}

func readBundleID(appPath string) string {
	candidates := []string{
		filepath.Join(appPath, "Contents/Info.plist"),
	}
	// iOS/iPadOS wrappers on Apple Silicon (Mole apps.sh).
	if matches, _ := filepath.Glob(filepath.Join(appPath, "Wrapper", "*.app", "Info.plist")); len(matches) > 0 {
		candidates = append(candidates, matches...)
	}
	for _, plist := range candidates {
		if !fsutil.Exists(plist) {
			continue
		}
		cmd := exec.Command("/usr/bin/plutil", "-extract", "CFBundleIdentifier", "raw", "-o", "-", plist)
		out, err := cmd.Output()
		if err != nil {
			continue
		}
		if id := strings.TrimSpace(string(out)); id != "" && id != "missing value" {
			return id
		}
	}
	return ""
}

func appSearchDirs() []string {
	home := fsutil.HomeDir()
	return []string{
		"/Applications",
		"/System/Applications",
		filepath.Join(home, "Applications"),
		"/opt/homebrew/Caskroom",
		"/usr/local/Caskroom",
		filepath.Join(home, "Library/Application Support/Setapp/Applications"),
	}
}

func listInstalled() []installedApp {
	seen := map[string]bool{}
	var apps []installedApp
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)

	addApp := func(appPath string) {
		if seen[appPath] {
			return
		}
		// Nested Wrapper payload — outer bundle already counted (Mole).
		if strings.Contains(appPath, "/Wrapper/") {
			return
		}
		name := strings.TrimSuffix(filepath.Base(appPath), ".app")
		if name == "" {
			return
		}
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
			if leaf := bidLeaf(bid); leaf != "" {
				tokens = append(tokens, normalizeToken(leaf))
			}
			mu.Lock()
			if !seen[appPath] {
				seen[appPath] = true
				apps = append(apps, installedApp{Path: appPath, Name: name, BundleID: bid, Tokens: tokens})
			}
			mu.Unlock()
		}(appPath, name)
	}

	for _, appsDir := range appSearchDirs() {
		if !fsutil.Exists(appsDir) {
			continue
		}
		// Mole: find -maxdepth 3 -iname '*.app'
		_ = filepath.WalkDir(appsDir, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			rel, _ := filepath.Rel(appsDir, path)
			depth := 0
			if rel != "." {
				depth = strings.Count(rel, string(os.PathSeparator)) + 1
			}
			if d.IsDir() && depth > 3 {
				return filepath.SkipDir
			}
			if d.IsDir() && strings.HasSuffix(strings.ToLower(d.Name()), ".app") {
				addApp(path)
				return filepath.SkipDir
			}
			return nil
		})
	}
	wg.Wait()
	return apps
}

func bidLeaf(bid string) string {
	if !isReverseDNS(bid) {
		return ""
	}
	i := strings.LastIndex(bid, ".")
	if i < 0 {
		return bid
	}
	return bid[i+1:]
}

// leftoverPatterns mirrors Mole find_app_files core user_patterns (name + bundle id).
func leftoverPatterns(home string, app installedApp) []string {
	name := app.Name
	bid := app.BundleID
	var out []string
	add := func(p string) {
		if p == "" {
			return
		}
		base := filepath.Base(p)
		if base == "" || base == "." || base == "Application Support" || base == "Caches" {
			return
		}
		out = append(out, p)
	}

	if len(name) >= 2 {
		add(filepath.Join(home, "Library/Application Support", name))
		add(filepath.Join(home, "Library/Caches", name))
		add(filepath.Join(home, "Library/Logs", name))
		add(filepath.Join(home, "Library/Preferences", name))
		add(filepath.Join(home, "Library/Preferences", name+".plist"))
		add(filepath.Join(home, "Library/Saved Application State", name+".savedState"))
		add(filepath.Join(home, ".config", name))
		add(filepath.Join(home, ".cache", name))
		add(filepath.Join(home, ".local/share", name))
	}

	nospace := strings.ReplaceAll(name, " ", "")
	underscore := strings.ReplaceAll(name, " ", "_")
	hyphen := strings.ReplaceAll(name, " ", "-")
	lower := strings.ToLower(name)
	if strings.Contains(name, " ") && len(name) > 3 {
		for _, v := range []string{nospace, underscore, hyphen} {
			add(filepath.Join(home, "Library/Application Support", v))
			add(filepath.Join(home, "Library/Caches", v))
			add(filepath.Join(home, "Library/Logs", v))
			add(filepath.Join(home, "Library/Preferences", v+".plist"))
			add(filepath.Join(home, "Library/Saved Application State", v+".savedState"))
		}
		for _, v := range []string{strings.ToLower(nospace), strings.ToLower(hyphen), strings.ToLower(underscore), lower} {
			add(filepath.Join(home, ".config", v))
			add(filepath.Join(home, ".cache", v))
			add(filepath.Join(home, ".local/share", v))
		}
	}

	if isReverseDNS(bid) {
		add(filepath.Join(home, "Library/Application Support", bid))
		add(filepath.Join(home, "Library/Caches", bid))
		add(filepath.Join(home, "Library/Logs", bid))
		add(filepath.Join(home, "Library/Saved Application State", bid+".savedState"))
		add(filepath.Join(home, "Library/Containers", bid))
		add(filepath.Join(home, "Library/WebKit", bid))
		add(filepath.Join(home, "Library/HTTPStorages", bid))
		add(filepath.Join(home, "Library/HTTPStorages", bid+".binarycookies"))
		add(filepath.Join(home, "Library/Cookies", bid+".binarycookies"))
		add(filepath.Join(home, "Library/Application Scripts", bid))
		add(filepath.Join(home, "Library/Autosave Information", bid))
		add(filepath.Join(home, "Library/Preferences", bid+".plist"))
		add(filepath.Join(home, "Library/Preferences", bid))
		add(filepath.Join(home, "Library/Caches/com.apple.nsurlsessiond/Downloads", bid))
	}
	return out
}

func entryMatchesApp(entryName string, app installedApp) bool {
	n := strings.ToLower(entryName)
	n = strings.TrimSuffix(n, ".plist")
	n = strings.TrimSuffix(n, ".savedstate")
	n = strings.TrimSuffix(n, ".binarycookies")
	token := normalizeToken(entryName)
	if token == "" || len(token) < 3 {
		return false
	}
	if app.BundleID != "" {
		bid := strings.ToLower(app.BundleID)
		if n == bid || strings.HasPrefix(n, bid+".") || strings.HasPrefix(n, bid+"-") {
			return true
		}
		if strings.Contains(n, bid) {
			return true
		}
	}
	for _, t := range app.Tokens {
		if t == "" || len(t) < 3 {
			continue
		}
		if token == t || strings.Contains(token, t) || strings.Contains(t, token) {
			return true
		}
	}
	return false
}

func bestAppMatch(entryName string, matches []installedApp) (installedApp, bool) {
	if len(matches) == 0 {
		return installedApp{}, false
	}
	if len(matches) == 1 {
		return matches[0], true
	}
	n := strings.ToLower(entryName)
	n = strings.TrimSuffix(n, ".plist")
	n = strings.TrimSuffix(n, ".savedstate")
	n = strings.TrimSuffix(n, ".binarycookies")
	// Prefer exact bundle-id / boundary match over fuzzy (Mole-style).
	for _, app := range matches {
		if app.BundleID == "" {
			continue
		}
		bid := strings.ToLower(app.BundleID)
		if n == bid || strings.HasPrefix(n, bid+".") || strings.HasPrefix(n, bid+"-") {
			return app, true
		}
	}
	return installedApp{}, false // ambiguous → orphan / skip attachment
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

func looksLikeOrphanName(entryName string) bool {
	n := strings.ToLower(entryName)
	n = strings.TrimSuffix(n, ".savedstate")
	n = strings.TrimSuffix(n, ".plist")
	if strings.HasPrefix(n, "com.apple.") || strings.HasPrefix(n, "apple.") {
		return false
	}
	// Mole orphan patterns: com.* / org.* / net.* / io.* (+ savedState).
	for _, p := range []string{"com.", "org.", "net.", "io.", "dev.", "app."} {
		if strings.HasPrefix(n, p) {
			return true
		}
	}
	return strings.HasSuffix(strings.ToLower(entryName), ".savedstate")
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

func rootLabel(full, home string) string {
	rel, err := filepath.Rel(home, full)
	if err != nil {
		return filepath.Dir(full)
	}
	return filepath.Dir(rel)
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

// ScanQuick returns installed apps with Mole-accurate .app sizes only (no leftover walks).
func ScanQuick() ScanResult {
	installed := listInstalled()
	results := make([]AppResult, len(installed))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)
	for i, app := range installed {
		wg.Add(1)
		go func(i int, app installedApp) {
			defer wg.Done()
			sem <- struct{}{}
			appBytes := sizeApp(app.Path)
			<-sem
			results[i] = AppResult{
				Path: app.Path, Name: app.Name, BundleID: app.BundleID,
				ByteSize: appBytes, AppBytes: appBytes,
				Leftovers: []jsonout.Item{},
				Safety:    "review", Explanation: "Installed application",
			}
		}(i, app)
	}
	wg.Wait()
	sort.Slice(results, func(i, j int) bool {
		if results[i].AppBytes != results[j].AppBytes {
			return results[i].AppBytes > results[j].AppBytes
		}
		return results[i].Name < results[j].Name
	})
	return ScanResult{Apps: results, Orphans: []jsonout.Item{}}
}

func makeLeftoverItem(full, name, root string, isDir bool, byteSize int64) jsonout.Item {
	intended := "review"
	explanation := "Leftover in " + root
	if strings.Contains(root, "Caches") || strings.Contains(full, "/Library/Caches/") {
		intended = "safe"
		explanation = "App cache · " + root
	} else if strings.Contains(root, "Logs") || strings.Contains(full, "/Library/Logs/") {
		intended = "safe"
		explanation = "App logs · " + root
	}
	return jsonout.Item{
		Path: full, Name: name, ByteSize: byteSize,
		Safety: safety.Classify(full, intended, safety.Opts{}),
		Kind: "leftover", Root: root, Explanation: explanation,
		IsDirectory: isDir, Category: categoryForRoot(root),
	}
}

func Scan() ScanResult {
	installed := listInstalled()
	home := fsutil.HomeDir()
	byApp := map[string][]jsonout.Item{}
	seen := map[string]bool{}
	installedBids := map[string]bool{}
	for _, a := range installed {
		byApp[a.Path] = nil
		if a.BundleID != "" {
			installedBids[strings.ToLower(a.BundleID)] = true
		}
	}

	type pending struct {
		full, name, root string
		isDir            bool
		appPath          string // empty → orphan
	}
	var jobs []pending

	// 1) Mole find_app_files-style exact patterns per installed app.
	for _, app := range installed {
		for _, p := range leftoverPatterns(home, app) {
			if !fsutil.Exists(p) || seen[p] || whitelist.Excludes(p) {
				continue
			}
			info, err := os.Lstat(p)
			if err != nil || info.Mode()&os.ModeSymlink != 0 {
				continue
			}
			seen[p] = true
			jobs = append(jobs, pending{
				full: p, name: filepath.Base(p), root: rootLabel(p, home),
				isDir: info.IsDir(), appPath: app.Path,
			})
		}
		// Group Containers: TeamID.bundleid boundary (Mole).
		if isReverseDNS(app.BundleID) {
			gc := filepath.Join(home, "Library/Group Containers")
			if ents, err := os.ReadDir(gc); err == nil {
				bid := strings.ToLower(app.BundleID)
				for _, ent := range ents {
					n := strings.ToLower(ent.Name())
					if !(strings.Contains(n, bid) || strings.HasSuffix(n, "."+bid) || strings.HasSuffix(n, bid)) {
						continue
					}
					full := filepath.Join(gc, ent.Name())
					if seen[full] || whitelist.Excludes(full) {
						continue
					}
					seen[full] = true
					jobs = append(jobs, pending{
						full: full, name: ent.Name(), root: "Library/Group Containers",
						isDir: ent.IsDir(), appPath: app.Path,
					})
				}
			}
		}
	}

	// 2) Scan Library roots for additional name matches + orphans.
	for _, root := range leftoverScanRoots {
		dir := filepath.Join(home, root)
		if !fsutil.Exists(dir) {
			continue
		}
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		prefsOnly := strings.HasSuffix(root, "Preferences")
		cookiesOnly := strings.HasSuffix(root, "Cookies")
		for _, ent := range entries {
			typ := ent.Type()
			if typ&os.ModeSymlink != 0 {
				continue
			}
			if prefsOnly && ent.IsDir() {
				continue
			}
			if cookiesOnly && ent.IsDir() {
				continue
			}
			full := filepath.Join(dir, ent.Name())
			if seen[full] || whitelist.Excludes(full) || !looksLikeAppData(ent.Name()) {
				continue
			}
			var matches []installedApp
			for _, app := range installed {
				if entryMatchesApp(ent.Name(), app) {
					matches = append(matches, app)
				}
			}
			if app, ok := bestAppMatch(ent.Name(), matches); ok {
				seen[full] = true
				jobs = append(jobs, pending{full: full, name: ent.Name(), root: root, isDir: ent.IsDir(), appPath: app.Path})
				continue
			}
			// Orphan: unmatched reverse-DNS style under Mole orphan roots, or any unmatched leftover elsewhere.
			isOrphanRoot := false
			for _, o := range orphanRoots {
				if root == o {
					isOrphanRoot = true
					break
				}
			}
			if len(matches) == 0 && (isOrphanRoot && looksLikeOrphanName(ent.Name()) || !isOrphanRoot) {
				// Skip Container/Group Container orphans (Mole: stubs / TeamID false positives).
				if root == "Library/Containers" || root == "Library/Group Containers" || root == "Library/Application Scripts" {
					continue
				}
				base := strings.ToLower(ent.Name())
				base = strings.TrimSuffix(base, ".savedstate")
				base = strings.TrimSuffix(base, ".plist")
				base = strings.TrimSuffix(base, ".binarycookies")
				if installedBids[base] {
					continue
				}
				seen[full] = true
				jobs = append(jobs, pending{full: full, name: ent.Name(), root: root, isDir: ent.IsDir(), appPath: ""})
			}
		}
	}

	type sized struct {
		item    jsonout.Item
		appPath string
		orphan  bool
	}
	sizedCh := make([]sized, len(jobs))
	appBytes := make([]int64, len(installed))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 6)

	for i, job := range jobs {
		wg.Add(1)
		go func(i int, job pending) {
			defer wg.Done()
			sem <- struct{}{}
			byteSize := sizeLeftover(job.full)
			<-sem
			if byteSize <= 0 {
				return
			}
			item := makeLeftoverItem(job.full, job.name, job.root, job.isDir, byteSize)
			if job.appPath == "" {
				item.Orphan = true
				item.Kind = "orphan"
				item.Explanation = "Orphaned data · " + job.root
				sizedCh[i] = sized{item: item, orphan: true}
				return
			}
			sizedCh[i] = sized{item: item, appPath: job.appPath}
		}(i, job)
	}
	for i, app := range installed {
		wg.Add(1)
		go func(i int, app installedApp) {
			defer wg.Done()
			sem <- struct{}{}
			appBytes[i] = sizeApp(app.Path)
			<-sem
		}(i, app)
	}
	wg.Wait()

	var orphans []jsonout.Item
	for _, s := range sizedCh {
		if s.item.Path == "" {
			continue
		}
		if s.orphan {
			orphans = append(orphans, s.item)
			continue
		}
		if s.appPath != "" {
			byApp[s.appPath] = append(byApp[s.appPath], s.item)
		}
	}

	results := make([]AppResult, len(installed))
	for i, app := range installed {
		leftovers := byApp[app.Path]
		if leftovers == nil {
			leftovers = []jsonout.Item{}
		}
		var leftoverBytes int64
		for _, l := range leftovers {
			leftoverBytes += l.ByteSize
		}
		ab := appBytes[i]
		results[i] = AppResult{
			Path: app.Path, Name: app.Name, BundleID: app.BundleID,
			ByteSize: ab, AppBytes: ab,
			LeftoverBytes: leftoverBytes, Leftovers: leftovers,
			Safety: "review", Explanation: "Installed application",
		}
	}

	sort.Slice(results, func(i, j int) bool {
		if results[i].AppBytes != results[j].AppBytes {
			return results[i].AppBytes > results[j].AppBytes
		}
		return results[i].Name < results[j].Name
	})
	sort.Slice(orphans, func(i, j int) bool { return orphans[i].ByteSize > orphans[j].ByteSize })
	return ScanResult{Apps: results, Orphans: orphans}
}
