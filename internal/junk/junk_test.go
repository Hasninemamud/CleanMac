package junk

import (
	"strings"
	"testing"
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
			strings.Contains(low, "_cacache")
		if !ok {
			t.Fatalf("unexpected path: %+v", r)
		}
	}
	for _, need := range []string{"userCaches", "browsers", "logs"} {
		if !cats[need] {
			t.Fatalf("missing category %s", need)
		}
	}
}
