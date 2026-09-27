package junk

import (
	"os"
	"path/filepath"
	"sort"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/safety"
)

type Rule struct {
	Category     string
	RelativePath string
	Safety       string
	Explanation  string
}

func Rules() []Rule {
	// Cache / rebuildable intermediates only — no Trash, logs, or archives.
	return []Rule{
		{Category: "userCaches", RelativePath: "Library/Caches", Safety: "safe", Explanation: "User application caches. Apps rebuild them."},
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
		{Category: "packageManagers", RelativePath: "Library/Caches/com.spotify.client", Safety: "safe", Explanation: "Spotify cache."},
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
	"temp":            "Temporary",
	"xcode":           "Xcode",
	"packageManagers": "Developer",
	"browsers":        "Browsers",
	"other":           "Other",
}

func enumerateTopLevel(target string, rule Rule) []jsonout.Item {
	entries, err := os.ReadDir(target)
	if err != nil {
		size := fsutil.DirectorySize(target, 200_000)
		if size <= 0 {
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
	var results []jsonout.Item
	for _, ent := range entries {
		full := filepath.Join(target, ent.Name())
		info, err := ent.Info()
		if err != nil {
			continue
		}
		if safety.IsBlocked(full, safety.Opts{}) || info.Mode()&os.ModeSymlink != 0 {
			continue
		}
		var size int64
		var modifiedAt float64
		modifiedAt = float64(info.ModTime().UnixMilli())
		if ent.IsDir() {
			size = fsutil.DirectorySize(full, 200_000)
		} else if info.Mode().IsRegular() {
			size = info.Size()
		} else {
			continue
		}
		if size <= 0 {
			continue
		}
		s := safety.Classify(full, rule.Safety, safety.Opts{})
		if s == "blocked" {
			continue
		}
		results = append(results, jsonout.Item{
			Path: full, Name: ent.Name(), ByteSize: size, Safety: s,
			Category: rule.Category, Explanation: rule.Explanation,
			ModifiedAt: modifiedAt, IsDirectory: ent.IsDir(),
		})
	}
	return results
}

func Scan(onProgress func(int, string)) []jsonout.Item {
	home := fsutil.HomeDir()
	var items []jsonout.Item
	visited := 0
	for _, rule := range Rules() {
		target := rule.RelativePath
		if !filepath.IsAbs(target) {
			target = filepath.Join(home, rule.RelativePath)
		}
		if !fsutil.Exists(target) {
			continue
		}
		visited++
		if onProgress != nil {
			onProgress(visited, target)
		}
		if safety.Classify(target, rule.Safety, safety.Opts{}) == "blocked" {
			continue
		}
		items = append(items, enumerateTopLevel(target, rule)...)
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ByteSize > items[j].ByteSize })
	return items
}
