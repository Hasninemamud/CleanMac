package fsutil

import (
	"os"
	"path/filepath"

	"github.com/Hasninemamud/CleanMac/internal/safety"
)

func HomeDir() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	h, _ := os.UserHomeDir()
	return h
}

func Exists(p string) bool {
	_, err := os.Lstat(p)
	return err == nil
}

// DirectorySize walks files under dir. Skips blocked paths and symlink dirs.
// maxEntries caps work so Clean scans stay responsive on huge cache trees.
func DirectorySize(dir string, maxEntries int) int64 {
	if maxEntries <= 0 {
		maxEntries = 12_000
	}
	if safety.IsBlocked(dir, safety.Opts{}) {
		return 0
	}
	var total int64
	count := 0
	stack := []string{dir}
	for len(stack) > 0 {
		current := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		entries, err := os.ReadDir(current)
		if err != nil {
			continue
		}
		for _, ent := range entries {
			count++
			if count > maxEntries {
				return total
			}
			typ := ent.Type()
			// DirEntry.Type avoids a stat for the common dir/symlink cases.
			if typ&os.ModeSymlink != 0 {
				continue
			}
			if ent.IsDir() {
				full := filepath.Join(current, ent.Name())
				// ponytail: only block-check directories — file-level checks doubled scan time.
				if safety.IsBlocked(full, safety.Opts{}) {
					continue
				}
				stack = append(stack, full)
				continue
			}
			if !typ.IsRegular() {
				continue
			}
			info, err := ent.Info()
			if err != nil {
				continue
			}
			total += info.Size()
		}
	}
	return total
}

func ShallowFolderSize(dir string) int64 {
	if safety.IsBlocked(dir, safety.Opts{}) {
		return 0
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	var total int64
	for _, ent := range entries {
		typ := ent.Type()
		if typ&os.ModeSymlink != 0 {
			continue
		}
		full := filepath.Join(dir, ent.Name())
		if ent.IsDir() {
			if safety.IsBlocked(full, safety.Opts{}) {
				continue
			}
			total += DirectorySize(full, 12_000)
			continue
		}
		if !typ.IsRegular() {
			continue
		}
		info, err := ent.Info()
		if err != nil {
			continue
		}
		total += info.Size()
	}
	return total
}
