package whitelist

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
)

func Path() string {
	return filepath.Join(fsutil.HomeDir(), "Library/Application Support/CleanMac/whitelist")
}

func Load() []string {
	f, err := os.Open(Path())
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		out = append(out, filepath.Clean(line))
	}
	return out
}

func Save(paths []string) error {
	p := Path()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	seen := map[string]bool{}
	var lines []string
	for _, x := range paths {
		x = filepath.Clean(strings.TrimSpace(x))
		if x == "" || seen[x] {
			continue
		}
		seen[x] = true
		lines = append(lines, x)
	}
	body := "# CleanMac whitelist — one absolute path per line\n" + strings.Join(lines, "\n")
	if len(lines) > 0 {
		body += "\n"
	}
	return os.WriteFile(p, []byte(body), 0o644)
}

func Add(path string) error {
	path = filepath.Clean(path)
	cur := Load()
	for _, c := range cur {
		if c == path {
			return nil
		}
	}
	return Save(append(cur, path))
}

func Remove(path string) error {
	path = filepath.Clean(path)
	cur := Load()
	var next []string
	for _, c := range cur {
		if c != path {
			next = append(next, c)
		}
	}
	return Save(next)
}

// Excludes reports true if path equals or is under a whitelisted prefix.
func Excludes(path string) bool {
	path = filepath.Clean(path)
	for _, w := range Load() {
		if path == w || strings.HasPrefix(path, w+string(os.PathSeparator)) {
			return true
		}
	}
	return false
}
