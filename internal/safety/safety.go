package safety

import (
	"path/filepath"
	"strings"
)

var blockedPrefixes = []string{
	"/System",
	"/usr",
	"/bin",
	"/sbin",
	"/private/var/db",
	"/Library/Apple",
	"/Library/OSAnalytics",
	"/Library/Updates",
}

type Opts struct {
	AllowApps bool
}

func Standardize(p string) string {
	if p == "" {
		return ""
	}
	p = filepath.Clean(p)
	if len(p) > 1 && strings.HasSuffix(p, "/") {
		p = strings.TrimRight(p, "/")
	}
	return p
}

func IsAppBundle(path string) bool {
	s := Standardize(path)
	return strings.HasPrefix(s, "/Applications/") && (strings.HasSuffix(s, ".app") || strings.Contains(s, ".app/"))
}

func IsBlocked(path string, opts Opts) bool {
	s := Standardize(path)
	if s == "/" || s == "/private" {
		return true
	}
	for _, prefix := range blockedPrefixes {
		if s == prefix || strings.HasPrefix(s, prefix+"/") {
			return true
		}
	}
	if !opts.AllowApps && IsAppBundle(s) {
		return true
	}
	return false
}

func Classify(path, intended string, opts Opts) string {
	if IsBlocked(path, opts) {
		return "blocked"
	}
	return intended
}

func CanTrash(path, safety string, opts Opts) bool {
	return safety != "blocked" && !IsBlocked(path, opts)
}
