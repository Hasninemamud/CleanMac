package junk

import (
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/safety"
	"github.com/Hasninemamud/CleanMac/internal/whitelist"
)

type Rule struct {
	Category     string
	RelativePath string
	Safety       string
	Explanation  string
}

// Rules are non-overlapping. Library/Caches is scanned once; children get categories by name.
func Rules() []Rule {
	tmp := os.TempDir()
	rules := []Rule{
		{Category: "userCaches", RelativePath: "Library/Caches", Safety: "safe", Explanation: "User application caches. Apps rebuild them."},
		{Category: "logs", RelativePath: "Library/Logs", Safety: "safe", Explanation: "Application logs in your home Library."},
		{Category: "trash", RelativePath: ".Trash", Safety: "review", Explanation: "Items already in Trash — emptying is optional."},
		{Category: "developer", RelativePath: "Library/Developer/Xcode/DerivedData", Safety: "safe", Explanation: "Xcode build intermediates."},
		{Category: "developer", RelativePath: "Library/Developer/CoreSimulator/Caches", Safety: "safe", Explanation: "Simulator caches."},
		{Category: "developer", RelativePath: ".npm/_cacache", Safety: "safe", Explanation: "npm package cache."},
		{Category: "developer", RelativePath: ".cache/yarn", Safety: "safe", Explanation: "Yarn cache."},
		{Category: "developer", RelativePath: ".gradle/caches", Safety: "safe", Explanation: "Gradle caches."},
		// AI / app support caches (fixed folders — never walk the whole disk).
		{Category: "aiTools", RelativePath: "Library/Application Support/Cursor/Cache", Safety: "safe", Explanation: "Cursor editor cache."},
		{Category: "aiTools", RelativePath: "Library/Application Support/Cursor/CachedData", Safety: "safe", Explanation: "Cursor cached data."},
		{Category: "aiTools", RelativePath: "Library/Application Support/Cursor/CachedExtensionVSIXs", Safety: "safe", Explanation: "Cursor extension cache."},
		{Category: "aiTools", RelativePath: "Library/Application Support/Claude/Cache", Safety: "safe", Explanation: "Claude desktop cache."},
		{Category: "aiTools", RelativePath: "Library/Application Support/Claude/Code Cache", Safety: "safe", Explanation: "Claude code cache."},
		{Category: "aiTools", RelativePath: "Library/Application Support/Code/Cache", Safety: "safe", Explanation: "VS Code cache."},
		{Category: "aiTools", RelativePath: "Library/Application Support/Code/CachedData", Safety: "safe", Explanation: "VS Code cached data."},
		{Category: "aiTools", RelativePath: ".cursor/ai-tracking", Safety: "safe", Explanation: "Cursor AI tracking cache."},
		{Category: "communication", RelativePath: "Library/Application Support/Slack/Cache", Safety: "safe", Explanation: "Slack cache."},
		{Category: "communication", RelativePath: "Library/Application Support/Slack/Code Cache", Safety: "safe", Explanation: "Slack code cache."},
		{Category: "communication", RelativePath: "Library/Application Support/discord/Cache", Safety: "safe", Explanation: "Discord cache."},
		{Category: "communication", RelativePath: "Library/Application Support/discord/Code Cache", Safety: "safe", Explanation: "Discord code cache."},
		{Category: "communication", RelativePath: "Library/Application Support/zoom.us/Cache", Safety: "safe", Explanation: "Zoom cache."},
		{Category: "cloud", RelativePath: "Library/Application Support/Dropbox/Cache", Safety: "safe", Explanation: "Dropbox cache."},
		{Category: "design", RelativePath: "Library/Application Support/Figma/Cache", Safety: "safe", Explanation: "Figma cache."},
		{Category: "design", RelativePath: "Library/Application Support/Adobe/CEP/extensions", Safety: "review", Explanation: "Adobe CEP extensions cache — review."},
	}
	if tmp != "" && tmp != "/" {
		rules = append(rules, Rule{Category: "temp", RelativePath: tmp, Safety: "review", Explanation: "User temp directory — review carefully."})
	}
	return rules
}

// CategoryLabels are Mole-aligned Clean taxonomy display names.
var CategoryLabels = map[string]string{
	"userCaches":    "App caches",
	"systemCaches":  "System caches",
	"logs":          "Logs",
	"browsers":      "Browsers",
	"developer":     "Developer",
	"aiTools":       "AI tools",
	"communication": "Communication",
	"cloud":         "Cloud storage",
	"design":        "Design tools",
	"temp":          "Temporary",
	"trash":         "Trash",
	// legacy keys from older scans
	"xcode":           "Developer",
	"packageManagers": "Developer",
	"misc":            "Temporary",
	"other":           "Temporary",
}

func Label(category string) string {
	if l, ok := CategoryLabels[category]; ok {
		return l
	}
	return category
}

func classifyCacheChild(name string) (category, explanation string) {
	low := strings.ToLower(name)
	switch {
	case strings.Contains(low, "safari"),
		strings.Contains(low, "chrome"),
		strings.Contains(low, "firefox"),
		strings.Contains(low, "edge"),
		strings.Contains(low, "brave"),
		strings.Contains(low, "arc"),
		strings.Contains(low, "thebrowser"),
		strings.Contains(low, "opera"),
		strings.Contains(low, "vivaldi"),
		low == "google",
		low == "chromium":
		return "browsers", "Browser cache"
	case strings.Contains(low, "cursor"),
		strings.Contains(low, "claude"),
		strings.Contains(low, "codex"),
		strings.Contains(low, "ollama"),
		strings.Contains(low, "chatgpt"),
		strings.Contains(low, "openai"),
		strings.Contains(low, "anthropic"),
		strings.Contains(low, "copilot"),
		strings.Contains(low, "gemini"),
		strings.Contains(low, "windsurf"),
		strings.Contains(low, "continue"),
		strings.Contains(low, "lm-studio"),
		strings.Contains(low, "lmstudio"):
		return "aiTools", "AI tool cache"
	case strings.Contains(low, "slack"),
		strings.Contains(low, "discord"),
		strings.Contains(low, "zoom"),
		strings.Contains(low, "teams"),
		strings.Contains(low, "telegram"),
		strings.Contains(low, "whatsapp"),
		strings.Contains(low, "signal"),
		strings.Contains(low, "skype"),
		strings.Contains(low, "wechat"),
		strings.Contains(low, "weixin"),
		strings.Contains(low, "lark"),
		strings.Contains(low, "feishu"),
		strings.Contains(low, "mattermost"):
		return "communication", "Communication app cache"
	case strings.Contains(low, "dropbox"),
		strings.Contains(low, "onedrive"),
		strings.Contains(low, "google.drive"),
		strings.Contains(low, "googledrive"),
		strings.Contains(low, "com.google.drive"),
		strings.Contains(low, "box."),
		strings.Contains(low, "mega."),
		strings.Contains(low, "synology"),
		strings.Contains(low, "baja"),
		strings.Contains(low, "icloud"):
		return "cloud", "Cloud storage cache"
	case strings.Contains(low, "adobe"),
		strings.Contains(low, "figma"),
		strings.Contains(low, "sketch"),
		strings.Contains(low, "affinity"),
		strings.Contains(low, "blender"),
		strings.Contains(low, "cinema4d"),
		strings.Contains(low, "premiere"),
		strings.Contains(low, "photoshop"),
		strings.Contains(low, "illustrator"),
		strings.Contains(low, "aftereffects"),
		strings.Contains(low, "indesign"),
		strings.Contains(low, "principle"),
		strings.Contains(low, "framer"):
		return "design", "Design tool cache"
	case strings.Contains(low, "cocoapods"),
		strings.Contains(low, "swiftpm"),
		strings.Contains(low, "pip"),
		strings.Contains(low, "homebrew"),
		strings.Contains(low, "yarn"),
		strings.Contains(low, "playwright"),
		strings.Contains(low, "npm"),
		strings.Contains(low, "gradle"),
		strings.Contains(low, "go-build"),
		strings.Contains(low, "cargo"),
		strings.Contains(low, "cypress"),
		strings.Contains(low, "turbo"),
		strings.Contains(low, "webpack"),
		strings.Contains(low, "node-gyp"),
		strings.Contains(low, "jetbrains"),
		strings.Contains(low, "com.apple.dt."),
		strings.Contains(low, "xcode"):
		return "developer", "Developer cache"
	case strings.HasPrefix(low, "com.apple."),
		strings.HasPrefix(low, "com.apple"),
		low == "cloudkit",
		low == "familymediastreaming",
		strings.Contains(low, "geoanalytics"),
		strings.Contains(low, "parsecd"),
		strings.Contains(low, "bird"),
		strings.Contains(low, "amsengagement"):
		return "systemCaches", "macOS system cache"
	case low == "temporaryitems" || strings.Contains(low, "temporary"):
		return "temp", "Temporary items cache"
	default:
		return "userCaches", "User application caches. Apps rebuild them."
	}
}

// runningCacheHolders returns lowercase process names that should keep their caches.
func runningCacheHolders() map[string]bool {
	out, err := exec.Command("ps", "-axo", "comm=").Output()
	if err != nil {
		return nil
	}
	set := map[string]bool{}
	for _, line := range strings.Split(string(out), "\n") {
		base := strings.ToLower(filepath.Base(strings.TrimSpace(line)))
		if base == "" || base == "?" {
			continue
		}
		set[base] = true
		// Strip .app helper suffixes commonly seen in cache folder names.
		set[strings.TrimSuffix(base, " helper")] = true
	}
	return set
}

func cacheHolderRunning(cacheName string, running map[string]bool) bool {
	if len(running) == 0 {
		return false
	}
	low := strings.ToLower(cacheName)
	// Bundle-id style: com.spotify.client → spotify
	parts := strings.Split(low, ".")
	candidates := []string{low, filepath.Base(low)}
	if len(parts) >= 2 {
		candidates = append(candidates, parts[len(parts)-1], parts[len(parts)-2])
	}
	for _, c := range candidates {
		c = strings.TrimSpace(c)
		if c == "" || len(c) < 3 {
			continue
		}
		if running[c] {
			return true
		}
		for proc := range running {
			if strings.Contains(proc, c) || strings.Contains(c, proc) {
				if len(proc) >= 3 {
					return true
				}
			}
		}
	}
	return false
}

func enumerateTopLevel(target string, rule Rule, running map[string]bool) []jsonout.Item {
	entries, err := os.ReadDir(target)
	if err != nil {
		size := fsutil.PathSize(target)
		if size <= 0 {
			return nil
		}
		if whitelist.Excludes(target) {
			return nil
		}
		s := safety.Classify(target, rule.Safety, safety.Opts{})
		if s == "blocked" {
			return nil
		}
		return []jsonout.Item{{
			Path: target, Name: filepath.Base(target), ByteSize: size,
			Safety: s, Category: Label(rule.Category), Explanation: rule.Explanation, IsDirectory: true,
		}}
	}

	type candidate struct {
		full, name, category, explanation, safety string
		isDir                                     bool
		size                                      int64
		modifiedAt                                float64
	}

	isCachesRoot := rule.Category == "userCaches" && strings.HasSuffix(target, "Library/Caches")
	cands := make([]candidate, 0, len(entries))
	for _, ent := range entries {
		full := filepath.Join(target, ent.Name())
		typ := ent.Type()
		if typ&os.ModeSymlink != 0 {
			continue
		}
		if whitelist.Excludes(full) || safety.IsBlocked(full, safety.Opts{}) {
			continue
		}
		cat, expl := rule.Category, rule.Explanation
		saf := rule.Safety
		if isCachesRoot {
			cat, expl = classifyCacheChild(ent.Name())
			if cacheHolderRunning(ent.Name(), running) {
				saf = "review"
				expl = expl + " (app running — skipped for safe clean)"
			}
		}
		c := candidate{
			full: full, name: ent.Name(), category: cat, explanation: expl, safety: saf, isDir: ent.IsDir(),
		}
		if ent.IsDir() {
			cands = append(cands, c)
			continue
		}
		if !typ.IsRegular() {
			continue
		}
		info, err := ent.Info()
		if err != nil {
			continue
		}
		c.size = info.Size()
		c.modifiedAt = float64(info.ModTime().UnixMilli())
		cands = append(cands, c)
	}

	// ponytail: parallel size walk; ceiling 8 workers.
	sem := make(chan struct{}, 8)
	var wg sync.WaitGroup
	for i := range cands {
		if !cands[i].isDir {
			continue
		}
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			sem <- struct{}{}
			cands[i].size = fsutil.PathSize(cands[i].full)
			<-sem
		}(i)
	}
	wg.Wait()

	var results []jsonout.Item
	for _, c := range cands {
		if c.size <= 0 {
			continue
		}
		s := safety.Classify(c.full, c.safety, safety.Opts{})
		if s == "blocked" {
			continue
		}
		results = append(results, jsonout.Item{
			Path: c.full, Name: c.name, ByteSize: c.size, Safety: s,
			Category: Label(c.category), Explanation: c.explanation,
			ModifiedAt: c.modifiedAt, IsDirectory: c.isDir,
		})
	}
	return results
}

func Scan(onProgress func(int, string)) []jsonout.Item {
	home := fsutil.HomeDir()
	rules := Rules()
	running := runningCacheHolders()
	buckets := make([][]jsonout.Item, len(rules))
	var wg sync.WaitGroup
	var progMu sync.Mutex
	visited := 0
	sem := make(chan struct{}, 6)

	for i, rule := range rules {
		wg.Add(1)
		go func(i int, rule Rule) {
			defer wg.Done()
			target := rule.RelativePath
			if !filepath.IsAbs(target) {
				target = filepath.Join(home, rule.RelativePath)
			}
			if !fsutil.Exists(target) {
				return
			}
			sem <- struct{}{}
			defer func() { <-sem }()

			progMu.Lock()
			visited++
			n := visited
			progMu.Unlock()
			if onProgress != nil {
				onProgress(n, target)
			}
			if whitelist.Excludes(target) || safety.Classify(target, rule.Safety, safety.Opts{}) == "blocked" {
				return
			}
			buckets[i] = enumerateTopLevel(target, rule, running)
		}(i, rule)
	}
	wg.Wait()

	var items []jsonout.Item
	for _, b := range buckets {
		items = append(items, b...)
	}
	sort.Slice(items, func(i, j int) bool {
		ti, tj := items[i].Category == Label("trash"), items[j].Category == Label("trash")
		if ti != tj {
			return !ti // Trash last
		}
		return items[i].ByteSize > items[j].ByteSize
	})
	return items
}
