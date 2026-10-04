package purge

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/safety"
)

var artifactNames = map[string]bool{
	"node_modules": true, "target": true, ".build": true, "build": true,
	"dist": true, ".next": true, ".turbo": true, "Pods": true,
	"DerivedData": true, ".gradle": true, "vendor": true, "__pycache__": true,
	".parcel-cache": true, "coverage": true,
}

var defaultRoots = []string{
	"Projects", "Developer", "dev", "Dev", "GitHub", "src", "code", "Code",
	"Documents", "Desktop", "Work", "workspace", "Workspace",
}

func walkForArtifacts(root string, out *[]jsonout.Item, maxDepth, max, depth int) {
	if depth > maxDepth || len(*out) >= max || safety.IsBlocked(root, safety.Opts{}) {
		return
	}
	entries, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, ent := range entries {
		if len(*out) >= max {
			break
		}
		if !ent.IsDir() {
			continue
		}
		info, err := ent.Info()
		if err != nil || info.Mode()&os.ModeSymlink != 0 {
			continue
		}
		if strings.HasPrefix(ent.Name(), ".") && !artifactNames[ent.Name()] {
			continue
		}
		full := filepath.Join(root, ent.Name())
		if safety.IsBlocked(full, safety.Opts{}) {
			continue
		}
		if artifactNames[ent.Name()] {
			mtime := info.ModTime()
			ageDays := time.Since(mtime).Hours() / 24
			byteSize := fsutil.DirectorySize(full, 30_000)
			if byteSize > 0 {
				intended := "safe"
				if ageDays < 7 {
					intended = "review"
				}
				*out = append(*out, jsonout.Item{
					Path: full, Name: ent.Name(),
					Project: filepath.Base(filepath.Dir(full)), ProjectPath: filepath.Dir(full),
					ByteSize: byteSize, Safety: safety.Classify(full, intended, safety.Opts{}),
					AgeDays: ageDays, Explanation: "Project artifact (" + ent.Name() + ")",
				})
			}
			continue
		}
		walkForArtifacts(full, out, maxDepth, max, depth+1)
	}
}

func Scan(onProgress func(int, string)) []jsonout.Item {
	home := fsutil.HomeDir()
	type bucket struct{ items []jsonout.Item }
	buckets := make([]bucket, len(defaultRoots))
	var wg sync.WaitGroup
	for i, name := range defaultRoots {
		root := filepath.Join(home, name)
		if !fsutil.Exists(root) {
			continue
		}
		wg.Add(1)
		go func(i int, root string) {
			defer wg.Done()
			if onProgress != nil {
				onProgress(i, root)
			}
			var local []jsonout.Item
			// ponytail: shallow project walk (depth 3, 120 hits) — raise if purge misses deep monorepos.
			walkForArtifacts(root, &local, 3, 120, 0)
			buckets[i].items = local
		}(i, root)
	}
	wg.Wait()
	var items []jsonout.Item
	for _, b := range buckets {
		items = append(items, b.items...)
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ByteSize > items[j].ByteSize })
	return items
}
