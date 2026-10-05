package optimize

import "testing"

func TestCatalogIDsUnique(t *testing.T) {
	seen := map[string]bool{}
	for _, a := range Catalog() {
		if a.ID == "" || a.Title == "" {
			t.Fatalf("incomplete action: %+v", a)
		}
		if seen[a.ID] {
			t.Fatalf("duplicate id %s", a.ID)
		}
		seen[a.ID] = true
	}
	for _, need := range []string{"ql", "fontcache", "sqlite", "notifications", "savedstate", "periodic"} {
		if !seen[need] {
			t.Fatalf("missing %s", need)
		}
	}
}

func TestDryRunSkipsWork(t *testing.T) {
	res := Run([]string{"ql", "dns", "periodic"}, true)
	if len(res.Actions) != 3 {
		t.Fatalf("got %d actions", len(res.Actions))
	}
	for _, a := range res.Actions {
		if a.Status != "ok" {
			t.Fatalf("%s status %s", a.ID, a.Status)
		}
	}
}
