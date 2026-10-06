package fsutil

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

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

// PathSize returns allocated bytes the Mole way (get_path_size_kb × 1024):
// .app → mdls kMDItemPhysicalSize, else du -skP; files → st_blocks; dirs → du -skP.
func PathSize(path string) int64 {
	return PathSizeOpts(path, safety.Opts{})
}

// PathSizeOpts is PathSize with safety options (AllowApps for measuring .app bundles).
func PathSizeOpts(path string, opts safety.Opts) int64 {
	if path == "" || !Exists(path) {
		return 0
	}
	if safety.IsBlocked(path, opts) {
		return 0
	}
	info, err := os.Lstat(path)
	if err != nil {
		return 0
	}

	// Mole: Spotlight physical size for .app bundles (APFS clones).
	if info.IsDir() && strings.HasSuffix(strings.ToLower(path), ".app") {
		if n, ok := mdlsPhysical(path); ok {
			return n
		}
		if n, ok := DuBytes(path); ok {
			return n
		}
		return DirectorySizeOpts(path, 100_000, opts)
	}

	if info.Mode()&os.ModeSymlink != 0 || info.Mode().IsRegular() {
		if st, ok := info.Sys().(*syscall.Stat_t); ok && st.Blocks > 0 {
			return st.Blocks * 512
		}
		return info.Size()
	}

	if info.IsDir() {
		if n, ok := DuBytes(path); ok {
			return n
		}
		return DirectorySizeOpts(path, 50_000, opts)
	}
	return 0
}

// DuBytes is Mole `du -skP` → bytes.
func DuBytes(path string) (int64, bool) {
	return DuBytesTimeout(path, 0)
}

// DuBytesTimeout is du -skP with an optional deadline. timeout<=0 means no limit.
func DuBytesTimeout(path string, timeout time.Duration) (int64, bool) {
	var cmd *exec.Cmd
	if timeout > 0 {
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()
		cmd = exec.CommandContext(ctx, "/usr/bin/du", "-skP", path)
	} else {
		cmd = exec.Command("/usr/bin/du", "-skP", path)
	}
	out, err := cmd.Output()
	if err != nil {
		return 0, false
	}
	fields := strings.Fields(string(out))
	if len(fields) == 0 {
		return 0, false
	}
	kb, err := strconv.ParseInt(fields[0], 10, 64)
	if err != nil || kb < 0 {
		return 0, false
	}
	return kb * 1024, true
}

// PathSizeQuick sizes dirs for Analyze UI: du with a short timeout, then capped walk.
// Keeps Map/Overview responsive on huge Library trees.
func PathSizeQuick(path string) int64 {
	if path == "" || !Exists(path) {
		return 0
	}
	if safety.IsBlocked(path, safety.Opts{}) {
		return 0
	}
	info, err := os.Lstat(path)
	if err != nil {
		return 0
	}
	if info.Mode()&os.ModeSymlink != 0 || info.Mode().IsRegular() {
		if st, ok := info.Sys().(*syscall.Stat_t); ok && st.Blocks > 0 {
			return st.Blocks * 512
		}
		return info.Size()
	}
	if !info.IsDir() {
		return 0
	}
	if n, ok := DuBytesTimeout(path, 8*time.Second); ok {
		return n
	}
	return DirectorySizeOpts(path, 20_000, safety.Opts{})
}

func mdlsPhysical(path string) (int64, bool) {
	cmd := exec.Command("/usr/bin/mdls", "-name", "kMDItemPhysicalSize", "-raw", path)
	out, err := cmd.Output()
	if err != nil {
		return 0, false
	}
	s := strings.TrimSpace(string(out))
	if s == "" || s == "(null)" {
		return 0, false
	}
	n, err := strconv.ParseInt(s, 10, 64)
	if err != nil || n <= 0 {
		return 0, false
	}
	return n, true
}

// DirectorySize walks files under dir (physical blocks). Caps entries for responsiveness.
// Prefer PathSize for Mole-accurate totals.
func DirectorySize(dir string, maxEntries int) int64 {
	return DirectorySizeOpts(dir, maxEntries, safety.Opts{})
}

// DirectorySizeOpts is DirectorySize with safety options (e.g. AllowApps for .app bundles).
func DirectorySizeOpts(dir string, maxEntries int, opts safety.Opts) int64 {
	if maxEntries <= 0 {
		maxEntries = 12_000
	}
	if safety.IsBlocked(dir, opts) {
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
			if typ&os.ModeSymlink != 0 {
				continue
			}
			if ent.IsDir() {
				full := filepath.Join(current, ent.Name())
				if safety.IsBlocked(full, opts) {
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
			if st, ok := info.Sys().(*syscall.Stat_t); ok && st.Blocks > 0 {
				total += st.Blocks * 512
			} else {
				total += info.Size()
			}
		}
	}
	return total
}

func ShallowFolderSize(dir string) int64 {
	return PathSize(dir)
}
