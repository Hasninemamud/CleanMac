package junk

import (
	"os"
	"path/filepath"
	"sort"
	"sync"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/safety"
	"github.com/Hasninemamud/CleanMac/internal/whitelist"
)

const sizeCap = 40_000

type Rule struct {
	Category     string
	RelativePath string
	Safety       string
	Explanation  string
}

func Rules() []Rule {
	return []Rule{
		{Category: "userCaches", RelativePath: "Library/Caches", Safety: "safe", Explanation: "User application caches. Apps rebuild them."},
		{Category: "logs", RelativePath: "Library/Logs", Safety: "safe", Explanation: "Application logs in your home Library."},
		{Category: "trash", RelativePath: ".Trash", Safety: "review", Explanation: "Items already in Trash — emptying is optional."},
		{Category: "temp", RelativePath: "Library/Caches/TemporaryItems", Safety: "safe", Explanation: "Temporary items cache."},
		{Category: "xcode", RelativePath: "Library/Developer/Xcode/DerivedData", Safety: "safe", Explanation: "Xcode build intermediates."},
		{Category: "xcode", RelativePath: "Library/Developer/CoreSimulator/Caches", Safety: "safe", Explanation: "Simulator caches."},
		{Category: "packageManagers", RelativePath: ".npm/_cacache", Safety: "safe", Explanation: "npm package cache."},
		{Category: "packageManagers", RelativePath: "Library/Caches/CocoaPods", Safety: "safe", Explanation: "CocoaPods cache."},
		{Category: "packageManagers", RelativePath: "Library/Caches/org.swift.swiftpm", Safety: "safe", Explanation: "Swift Package Manager cache."},
		{Category: "packageManagers", RelativePath: "Library/Caches/pip", Safety: "safe", Explanation: "pip package cache."},
		{Category: "packageManagers", RelativePath: "Library/Caches/Homebrew", Safety: "safe", Explanation: "Homebrew download cache."},
		{Category: "packageManagers", RelativePath: ".cache/yarn", Safety: "safe", Explanation: "Yarn cache."},
		{Category: "packageManagers", RelativePath: "Library/Caches/Yarn", Safety: "safe", Explanation: "Yarn cache (Library)."},
		{Category: "packageManagers", RelativePath: "Library/Caches/ms-playwright", Safety: "safe", Explanation: "Playwright browser downloads."},
		{Category: "misc", RelativePath: "Library/Caches/com.spotify.client", Safety: "safe", Explanation: "Spotify cache."},
		{Category: "browsers", RelativePath: "Library/Caches/com.apple.Safari", Safety: "safe", Explanation: "Safari cache."},
		{Category: "browsers", RelativePath: "Library/Caches/Google/Chrome", Safety: "safe", Explanation: "Chrome cache."},
		{Category: "browsers", RelativePath: "Library/Caches/Firefox", Safety: "safe", Explanation: "Firefox cache."},
		{Category: "browsers", RelativePath: "Library/Caches/Microsoft Edge", Safety: "safe", Explanation: "Edge cache."},
		{Category: "browsers", RelativePath: "Library/Caches/Arc", Safety: "safe", Explanation: "Arc browser cache."},
		{Category: "browsers", RelativePath: "Library/Caches/company.thebrowser.Browser", Safety: "safe", Explanation: "Arc/Dia browser cache."},
		{Category: "browsers", RelativePath: "Library/Caches/BraveSoftware", Safety: "safe", Explanation: "Brave browser cache."},
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

func enumerateTopLevel(target string, rule Rule) []jsonout.Item {
	entries, err := os.ReadDir(target)
	if err != nil {
		size := fsutil.DirectorySize(target, sizeCap)
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
		full       string
		name       string
		isDir      bool
		size       int64
		modifiedAt float64
	}
	cands := make([]candidate, 0, len(entries))
	for _, ent := range entries {
		full := filepath.Join(target, ent.Name())
		info, err := ent.Info()
		if err != nil {
			continue
		}
		if whitelist.Excludes(full) || safety.IsBlocked(full, safety.Opts{}) || info.Mode()&os.ModeSymlink != 0 {
			continue
		}
		if !ent.IsDir() && !info.Mode().IsRegular() {
			continue
		}
		cands = append(cands, candidate{
			full: full, name: ent.Name(), isDir: ent.IsDir(),
			size: info.Size(), modifiedAt: float64(info.ModTime().UnixMilli()),
		})
	}

	// ponytail: parallel size walk; ceiling ~8 workers — bump if Clean still feels slow on huge caches.
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
			cands[i].size = fsutil.DirectorySize(cands[i].full, sizeCap)
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
			Category: rule.Category, Explanation: rule.Explanation,
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
