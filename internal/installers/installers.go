package installers

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/safety"
)

var installerExt = map[string]bool{
	".dmg": true, ".pkg": true, ".mpkg": true, ".iso": true, ".xip": true,
}

var zipInstaller = regexp.MustCompile(`(?i)(setup|installer|install)`)

func isInstallerName(name string) bool {
	lower := strings.ToLower(name)
	ext := filepath.Ext(lower)
	if installerExt[ext] {
		return true
	}
	return ext == ".zip" && zipInstaller.MatchString(name)
}

func scanDir(dir, source string, out *[]jsonout.Item, max, depth, maxDepth int) {
	if !fsutil.Exists(dir) || len(*out) >= max || depth > maxDepth {
		return
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, ent := range entries {
		if len(*out) >= max {
			break
		}
		if strings.HasPrefix(ent.Name(), ".") {
			continue
		}
		full := filepath.Join(dir, ent.Name())
		info, err := ent.Info()
		if err != nil {
			continue
		}
		if safety.IsBlocked(full, safety.Opts{}) || info.Mode()&os.ModeSymlink != 0 {
			continue
		}
		if ent.IsDir() {
			if depth < maxDepth {
				combined := ent.Name() + source
				if regexp.MustCompile(`(?i)download|mail|telegram|desktop|icloud`).MatchString(combined) {
					scanDir(full, source, out, max, depth+1, maxDepth)
				}
			}
			continue
		}
		if !info.Mode().IsRegular() || !isInstallerName(ent.Name()) {
			continue
		}
		*out = append(*out, jsonout.Item{
			Path: full, Name: ent.Name(), ByteSize: info.Size(),
			Safety: safety.Classify(full, "safe", safety.Opts{}),
			Source: source, Explanation: "Installer in " + source,
			ModifiedAt: float64(info.ModTime().UnixMilli()),
		})
	}
}

func Scan() []jsonout.Item {
	home := fsutil.HomeDir()
	var items []jsonout.Item
	targets := []struct{ dir, source string }{
		{filepath.Join(home, "Downloads"), "Downloads"},
		{filepath.Join(home, "Desktop"), "Desktop"},
		{filepath.Join(home, "Library/Caches/Homebrew/downloads"), "Homebrew"},
		{filepath.Join(home, "Library/Mobile Documents/com~apple~CloudDocs"), "iCloud"},
		{filepath.Join(home, "Library/Mail Downloads"), "Mail"},
		{filepath.Join(home, "Library/Group Containers"), "Containers"},
	}
	groupRoot := filepath.Join(home, "Library/Group Containers")
	if fsutil.Exists(groupRoot) {
		if groups, err := os.ReadDir(groupRoot); err == nil {
			for _, g := range groups {
				if regexp.MustCompile(`(?i)telegram|whatsapp|signal`).MatchString(g.Name()) {
					targets = append(targets, struct{ dir, source string }{filepath.Join(groupRoot, g.Name()), "Chat"})
				}
			}
		}
	}
	for _, t := range targets {
		maxDepth := 1
		if t.source == "Containers" || t.source == "Chat" {
			maxDepth = 3
		}
		scanDir(t.dir, t.source, &items, 600, 0, maxDepth)
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ByteSize > items[j].ByteSize })
	return items
}
