package junk

import (
	"os"
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
	return []Rule{
		{Category: "userCaches", RelativePath: "Library/Caches", Safety: "safe", Explanation: "User application caches. Apps rebuild them."},
		{Category: "logs", RelativePath: "Library/Logs", Safety: "safe", Explanation: "Application logs in your home Library."},
		{Category: "trash", RelativePath: ".Trash", Safety: "review", Explanation: "Items already in Trash — emptying is optional."},
		{Category: "xcode", RelativePath: "Library/Developer/Xcode/DerivedData", Safety: "safe", Explanation: "Xcode build intermediates."},
		{Category: "xcode", RelativePath: "Library/Developer/CoreSimulator/Caches", Safety: "safe", Explanation: "Simulator caches."},
		{Category: "packageManagers", RelativePath: ".npm/_cacache", Safety: "safe", Explanation: "npm package cache."},
		{Category: "packageManagers", RelativePath: ".cache/yarn", Safety: "safe", Explanation: "Yarn cache."},
	}
}

var CategoryLabels = map[string]string{
	"userCaches":      "App caches",
	"logs":            "Logs",
	"trash":           "Trash",
	"temp":            "Temporary",
	"xcode":           "Xcode",
	"packageManagers": "Developer",
	"browsers":        "Browsers",
	"misc":            "Misc",
	"other":           "Other",
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
		low == "google", // Library/Caches/Google/…
		low == "chromium":
		return "browsers", "Browser cache"
	case strings.Contains(low, "cocoapods"),
		strings.Contains(low, "swiftpm"),
		strings.Contains(low, "pip"),
		strings.Contains(low, "homebrew"),
		strings.Contains(low, "yarn"),
		strings.Contains(low, "playwright"),
		strings.Contains(low, "npm"),
		strings.Contains(low, "gradle"),
		strings.Contains(low, "go-build"):
		return "packageManagers", "Developer cache"
	case strings.Contains(low, "spotify"):
		return "misc", "Spotify cache"
	case low == "temporaryitems" || strings.Contains(low, "temporary"):
		return "temp", "Temporary items cache"
	default:
		return "userCaches", "User application caches. Apps rebuild them."
	}
}

func enumerateTopLevel(target string, rule Rule) []jsonout.Item {
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
			Safety: s, Category: rule.Category, Explanation: rule.Explanation, IsDirectory: true,
		}}
	}

	type candidate struct {
		full, name, category, explanation string
		isDir                             bool
		size                              int64
		modifiedAt                        float64
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
		if isCachesRoot {
			cat, expl = classifyCacheChild(ent.Name())
		}
		c := candidate{
			full: full, name: ent.Name(), category: cat, explanation: expl, isDir: ent.IsDir(),
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
		s := safety.Classify(c.full, rule.Safety, safety.Opts{})
		if s == "blocked" {
			continue
		}
		results = append(results, jsonout.Item{
			Path: c.full, Name: c.name, ByteSize: c.size, Safety: s,
			Category: c.category, Explanation: c.explanation,
			ModifiedAt: c.modifiedAt, IsDirectory: c.isDir,
		})
	}
	return results
}

func Scan(onProgress func(int, string)) []jsonout.Item {
	home := fsutil.HomeDir()
	rules := Rules()
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
			buckets[i] = enumerateTopLevel(target, rule)
		}(i, rule)
	}
	wg.Wait()

	var items []jsonout.Item
	for _, b := range buckets {
		items = append(items, b...)
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ByteSize > items[j].ByteSize })
	return items
}
