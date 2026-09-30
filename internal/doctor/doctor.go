package doctor

import (
	"os"
	"os/exec"
	"path/filepath"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/oplog"
	"github.com/Hasninemamud/CleanMac/internal/whitelist"
)

type Check struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	Status  string `json:"status"` // ok|warn|fail
	Detail  string `json:"detail"`
}

func Run() []Check {
	var out []Check
	if _, err := exec.LookPath("cleanmac"); err == nil {
		out = append(out, Check{ID: "cli-path", Title: "cleanmac on PATH", Status: "ok", Detail: "found in PATH"})
	} else {
		out = append(out, Check{ID: "cli-path", Title: "cleanmac on PATH", Status: "warn", Detail: "not on PATH — app uses bundled binary"})
	}
	wl := whitelist.Path()
	if _, err := os.Stat(wl); err == nil {
		n := len(whitelist.Load())
		out = append(out, Check{ID: "whitelist", Title: "Whitelist", Status: "ok", Detail: filepath.Base(wl) + " · " + itoa(n) + " entries"})
	} else {
		out = append(out, Check{ID: "whitelist", Title: "Whitelist", Status: "ok", Detail: "none yet (optional)"})
	}
	if _, err := os.Stat(oplog.Path()); err == nil {
		out = append(out, Check{ID: "oplog", Title: "Operations log", Status: "ok", Detail: oplog.Path()})
	} else {
		out = append(out, Check{ID: "oplog", Title: "Operations log", Status: "ok", Detail: "no operations yet"})
	}
	home := fsutil.HomeDir()
	caches := filepath.Join(home, "Library/Caches")
	if st, err := os.Stat(caches); err == nil && st.IsDir() {
		out = append(out, Check{ID: "library-caches", Title: "Library/Caches readable", Status: "ok", Detail: caches})
	} else {
		out = append(out, Check{ID: "library-caches", Title: "Library/Caches readable", Status: "fail", Detail: errString(err)})
	}
	return out
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [16]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}

func errString(err error) string {
	if err == nil {
		return "missing"
	}
	return err.Error()
}
