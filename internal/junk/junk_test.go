package junk

import (
	"strings"
	"testing"
)

func TestRulesAreCacheOnly(t *testing.T) {
	forbidden := []string{"logs", "trash", "archives", "devicesupport", "pnpm/store"}
	for _, r := range Rules() {
		low := strings.ToLower(r.RelativePath + " " + r.Category)
		for _, bad := range forbidden {
			if strings.Contains(low, bad) {
				t.Fatalf("non-cache rule: %+v", r)
			}
		}
		// Must live under a cache-ish path or DerivedData (rebuildable).
		ok := strings.Contains(low, "cache") ||
			strings.Contains(low, "deriveddata") ||
			strings.Contains(low, "_cacache")
		if !ok {
			t.Fatalf("expected cache path: %+v", r)
		}
	}
}
