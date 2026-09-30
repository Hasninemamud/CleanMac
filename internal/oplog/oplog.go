package oplog

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
)

type Entry struct {
	Time    string   `json:"time"`
	Action  string   `json:"action"`
	Paths   []string `json:"paths,omitempty"`
	Detail  string   `json:"detail,omitempty"`
	Bytes   int64    `json:"bytes,omitempty"`
}

func Path() string {
	return filepath.Join(fsutil.HomeDir(), "Library/Logs/CleanMac/operations.log")
}

func Append(action string, paths []string, bytes int64, detail string) {
	dir := filepath.Dir(Path())
	_ = os.MkdirAll(dir, 0o755)
	e := Entry{
		Time:   time.Now().Format(time.RFC3339),
		Action: action,
		Paths:  paths,
		Bytes:  bytes,
		Detail: detail,
	}
	b, err := json.Marshal(e)
	if err != nil {
		return
	}
	f, err := os.OpenFile(Path(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.Write(append(b, '\n'))
}

func Tail(n int) []Entry {
	if n <= 0 {
		n = 50
	}
	b, err := os.ReadFile(Path())
	if err != nil {
		return nil
	}
	lines := splitLines(string(b))
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	var out []Entry
	for _, line := range lines {
		var e Entry
		if json.Unmarshal([]byte(line), &e) == nil {
			out = append(out, e)
		}
	}
	return out
}

func splitLines(s string) []string {
	var out []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			if i > start {
				out = append(out, s[start:i])
			}
			start = i + 1
		}
	}
	if start < len(s) {
		out = append(out, s[start:])
	}
	return out
}
