package ai

import "testing"

func TestDetectRootsNoWalk(t *testing.T) {
	roots := DetectRoots()
	for _, r := range roots {
		if r == "" {
			t.Fatal("empty root")
		}
	}
	_ = HasData()
	_ = PresenceReport()
}

func TestProbeBands(t *testing.T) {
	seen := map[string]bool{}
	for _, p := range probeList() {
		seen[p.Band] = true
		if p.Rel == "" || p.Label == "" {
			t.Fatalf("incomplete probe: %+v", p)
		}
	}
	for _, need := range []string{BandCaches, BandSessions, BandIdle} {
		if !seen[need] {
			t.Fatalf("missing band %s", need)
		}
	}
}

func TestDefaultCheckedOnlyCaches(t *testing.T) {
	items := Scan()
	checked := map[string]bool{}
	for _, p := range DefaultChecked(items) {
		checked[p] = true
	}
	for _, it := range items {
		if checked[it.Path] && it.Category != BandCaches {
			t.Fatalf("non-cache default-checked: %s (%s)", it.Path, it.Category)
		}
	}
}
