package junk

import (
	"strings"
	"testing"
	"time"
)

func TestRulesCoverCleanCategories(t *testing.T) {
	cats := map[string]bool{}
	for _, r := range Rules() {
		cats[r.Category] = true
		low := strings.ToLower(r.RelativePath)
		ok := strings.Contains(low, "cache") ||
			strings.Contains(low, "log") ||
			strings.Contains(low, "trash") ||
			strings.Contains(low, "deriveddata") ||
			strings.Contains(low, "_cacache") ||
			strings.Contains(low, "yarn") ||
			strings.Contains(low, "gradle") ||
			strings.Contains(low, "cursor") ||
			strings.Contains(low, "claude") ||
			strings.Contains(low, "code/") ||
			strings.Contains(low, "slack") ||
			strings.Contains(low, "discord") ||
			strings.Contains(low, "zoom") ||
			strings.Contains(low, "dropbox") ||
			strings.Contains(low, "figma") ||
			strings.Contains(low, "adobe") ||
			strings.Contains(low, "ai-tracking") ||
			strings.Contains(low, "/t/") || // user temp
			strings.HasPrefix(low, "/var/folders") ||
			strings.HasPrefix(low, "/tmp")
		if !ok {
			t.Fatalf("unexpected path: %+v", r)
		}
	}
	for _, need := range []string{"userCaches", "logs", "aiTools"} {
		if !cats[need] {
			t.Fatalf("missing category %s", need)
		}
	}
	// No overlapping Library/Caches/* rules — those were double-scanned before.
	for _, r := range Rules() {
		if r.RelativePath != "Library/Caches" && strings.HasPrefix(r.RelativePath, "Library/Caches/") {
			t.Fatalf("duplicate Caches rule (would double-scan): %s", r.RelativePath)
		}
		if r.RelativePath != "Library/Logs" && strings.HasPrefix(r.RelativePath, "Library/Logs/") {
			t.Fatalf("duplicate Logs rule (would double-scan): %s", r.RelativePath)
		}
	}
}

func TestClassifyCacheChild(t *testing.T) {
	cases := map[string]string{
		"Google":                    "browsers",
		"com.apple.Safari":          "browsers",
		"BraveSoftware":             "browsers",
		"Homebrew":                  "developer",
		"ms-playwright":             "developer",
		"com.spotify.client":        "userCaches",
		"TemporaryItems":            "temp",
		"com.apple.helpui":          "systemCaches",
		"com.apple.QuickLook":       "systemCaches",
		"Cursor":                    "aiTools",
		"com.anthropic.claude":      "aiTools",
		"Slack":                     "communication",
		"discord":                   "communication",
		"us.zoom.xos":               "communication",
		"com.dropbox.DropboxMacUpdate": "cloud",
		"Figma":                     "design",
		"Adobe":                     "design",
		"com.apple.dt.Xcode":        "developer",
	}
	for name, want := range cases {
		got, _ := classifyCacheChild(name)
		if got != want {
			t.Fatalf("%s: got %s want %s", name, got, want)
		}
	}
}

func TestLabelTaxonomy(t *testing.T) {
	for _, key := range []string{
		"userCaches", "systemCaches", "logs", "browsers", "developer",
		"aiTools", "communication", "cloud", "design", "temp", "trash",
	} {
		if Label(key) == key {
			t.Fatalf("missing label for %s", key)
		}
	}
	if Label("trash") != "Trash" {
		t.Fatalf("trash label = %q", Label("trash"))
	}
}

func TestScanCompletesQuickly(t *testing.T) {
	start := time.Now()
	items := Scan(nil)
	elapsed := time.Since(start)
	if elapsed > 3*time.Second {
		t.Fatalf("Scan took %v (>3s), items=%d", elapsed, len(items))
	}
	t.Logf("Scan %v items=%d", elapsed, len(items))
	// Trash (if present) must sort last among equal handling.
	for i := 0; i+1 < len(items); i++ {
		if items[i].Category == Label("trash") && items[i+1].Category != Label("trash") {
			t.Fatalf("Trash not last: idx %d then %q", i, items[i+1].Category)
		}
	}
}
