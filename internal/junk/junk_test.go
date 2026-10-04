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
			strings.Contains(low, "yarn")
		if !ok {
			t.Fatalf("unexpected path: %+v", r)
		}
	}
	for _, need := range []string{"userCaches", "logs"} {
		if !cats[need] {
			t.Fatalf("missing category %s", need)
		}
	}
	// No overlapping Library/Caches/* rules — those were double-scanned before.
	for _, r := range Rules() {
		if r.RelativePath != "Library/Caches" && strings.HasPrefix(r.RelativePath, "Library/Caches/") {
			t.Fatalf("duplicate Caches rule (would double-scan): %s", r.RelativePath)
		}
	}
}

func TestClassifyCacheChild(t *testing.T) {
	cases := map[string]string{
		"Google": "browsers", "com.apple.Safari": "browsers", "BraveSoftware": "browsers",
		"Homebrew": "packageManagers", "ms-playwright": "packageManagers",
		"com.spotify.client": "misc", "TemporaryItems": "temp",
		"com.apple.helpui": "userCaches",
	}
	for name, want := range cases {
		got, _ := classifyCacheChild(name)
		if got != want {
			t.Fatalf("%s: got %s want %s", name, got, want)
		}
	}
}

func TestScanCompletesQuickly(t *testing.T) {
	start := time.Now()
	items := Scan(nil)
	elapsed := time.Since(start)
	if elapsed > 2*time.Second {
		t.Fatalf("Scan took %v (>2s), items=%d", elapsed, len(items))
	}
	t.Logf("Scan %v items=%d", elapsed, len(items))
}
