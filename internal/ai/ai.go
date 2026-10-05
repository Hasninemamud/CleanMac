package ai

import (
	"path/filepath"
	"sort"
	"strings"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/safety"
	"github.com/Hasninemamud/CleanMac/internal/whitelist"
)

// Band groups AI cleanup items for the Moon review UI.
const (
	BandCaches   = "caches"   // checked by default
	BandSessions = "sessions" // unchecked
	BandIdle     = "idle"     // unchecked
)

type probe struct {
	Rel   string
	Band  string
	Label string
	Safe  string
}

// DetectRoots returns fixed AI folders that exist (no disk walk).
func DetectRoots() []string {
	home := fsutil.HomeDir()
	var found []string
	for _, p := range probeList() {
		full := p.Rel
		if !filepath.IsAbs(full) {
			full = filepath.Join(home, p.Rel)
		}
		if fsutil.Exists(full) {
			found = append(found, full)
		}
	}
	return found
}

// HasData is true when any known AI folder exists.
func HasData() bool {
	return len(DetectRoots()) > 0
}

func probeList() []probe {
	return []probe{
		// Caches / old versions — default checked
		{Rel: "Library/Application Support/Cursor/Cache", Band: BandCaches, Label: "Cursor cache", Safe: "safe"},
		{Rel: "Library/Application Support/Cursor/CachedData", Band: BandCaches, Label: "Cursor cached data", Safe: "safe"},
		{Rel: "Library/Application Support/Cursor/CachedExtensionVSIXs", Band: BandCaches, Label: "Cursor extension cache", Safe: "safe"},
		{Rel: "Library/Application Support/Claude/Cache", Band: BandCaches, Label: "Claude cache", Safe: "safe"},
		{Rel: "Library/Application Support/Claude/Code Cache", Band: BandCaches, Label: "Claude code cache", Safe: "safe"},
		{Rel: "Library/Application Support/Code/Cache", Band: BandCaches, Label: "VS Code cache", Safe: "safe"},
		{Rel: "Library/Application Support/Code/CachedData", Band: BandCaches, Label: "VS Code cached data", Safe: "safe"},
		{Rel: ".cursor/ai-tracking", Band: BandCaches, Label: "Cursor AI tracking", Safe: "safe"},
		{Rel: ".ollama/models/.cache", Band: BandCaches, Label: "Ollama model cache", Safe: "safe"},
		// Sessions / worktrees — unchecked
		{Rel: ".cursor/worktrees", Band: BandSessions, Label: "Cursor worktrees", Safe: "review"},
		{Rel: ".cursor/projects", Band: BandSessions, Label: "Cursor projects metadata", Safe: "review"},
		{Rel: ".codex", Band: BandSessions, Label: "Codex sessions", Safe: "review"},
		{Rel: ".claude", Band: BandSessions, Label: "Claude CLI sessions", Safe: "review"},
		// Idle tool installs — unchecked
		{Rel: ".local/share/ollama", Band: BandIdle, Label: "Ollama local share", Safe: "review"},
		{Rel: ".continue", Band: BandIdle, Label: "Continue.dev data", Safe: "review"},
		{Rel: ".windsurf", Band: BandIdle, Label: "Windsurf data", Safe: "review"},
	}
}

// Scan sizes known AI folders on demand.
func Scan() []jsonout.Item {
	home := fsutil.HomeDir()
	var items []jsonout.Item
	for _, p := range probeList() {
		full := p.Rel
		if !filepath.IsAbs(full) {
			full = filepath.Join(home, p.Rel)
		}
		if !fsutil.Exists(full) || whitelist.Excludes(full) {
			continue
		}
		s := safety.Classify(full, p.Safe, safety.Opts{})
		if s == "blocked" {
			continue
		}
		size := fsutil.PathSize(full)
		if size <= 0 {
			continue
		}
		items = append(items, jsonout.Item{
			Path: full, Name: p.Label, ByteSize: size, Safety: s,
			Category: p.Band, Explanation: p.Label + " (" + p.Band + ")",
			IsDirectory: true,
		})
	}
	sort.Slice(items, func(i, j int) bool {
		// caches first, then sessions, then idle; within band by size.
		bi, bj := bandRank(items[i].Category), bandRank(items[j].Category)
		if bi != bj {
			return bi < bj
		}
		return items[i].ByteSize > items[j].ByteSize
	})
	return items
}

func bandRank(b string) int {
	switch strings.ToLower(b) {
	case BandCaches:
		return 0
	case BandSessions:
		return 1
	case BandIdle:
		return 2
	default:
		return 9
	}
}

// DefaultChecked returns paths in the caches band (UI pre-selects these).
func DefaultChecked(items []jsonout.Item) []string {
	var out []string
	for _, it := range items {
		if it.Category == BandCaches && it.Safety == "safe" {
			out = append(out, it.Path)
		}
	}
	return out
}

// PresenceReport is a tiny JSON-friendly detection result (no sizing).
func PresenceReport() map[string]any {
	roots := DetectRoots()
	return map[string]any{
		"hasData": len(roots) > 0,
		"roots":   roots,
	}
}
