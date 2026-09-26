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
func DirectorySize(dir string, maxEntries int) int64 {
	if maxEntries <= 0 {
		maxEntries = 200_000
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
			full := filepath.Join(current, ent.Name())
			if safety.IsBlocked(full, safety.Opts{}) {
				continue
			}
			info, err := ent.Info()
			if err != nil {
				continue
			}
			mode := info.Mode()
			if mode&os.ModeSymlink != 0 {
				continue
			}
			if ent.IsDir() {
				stack = append(stack, full)
			} else if mode.IsRegular() {
				total += info.Size()
			}
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
		full := filepath.Join(dir, ent.Name())
		if safety.IsBlocked(full, safety.Opts{}) {
			continue
		}
		info, err := ent.Info()
		if err != nil {
			continue
		}
		if info.Mode()&os.ModeSymlink != 0 {
			continue
		}
		if ent.IsDir() {
			total += DirectorySize(full, 200_000)
		} else if info.Mode().IsRegular() {
			total += info.Size()
		}
	}
	return total
}
