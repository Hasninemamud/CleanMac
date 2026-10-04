package apps

import (
	"testing"
	"time"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/safety"
)

func TestAppBundleSizeNotZero(t *testing.T) {
	p := "/Applications/Cursor.app"
	if !fsutil.Exists(p) {
		t.Skip("Cursor.app not installed")
	}
	if !safety.IsBlocked(p, safety.Opts{}) {
		t.Fatal("apps should be blocked by default (trash safety)")
	}
	sz := sizeApp(p)
	du, ok := fsutil.DuBytes(p)
	if !ok {
		t.Fatal("du failed")
	}
	// mdls may differ from du; must be within 5% and not a capped undercount.
	if sz < 800_000_000 {
		t.Fatalf("expected full .app size (~1GB), got %d", sz)
	}
	diff := sz - du
	if diff < 0 {
		diff = -diff
	}
	if sz < du && float64(diff) > float64(du)*0.05 {
		t.Fatalf("sizeApp %d under-reports du %d", sz, du)
	}
}

func TestScanQuickFast(t *testing.T) {
	start := time.Now()
	r := ScanQuick()
	elapsed := time.Since(start)
	// Broader Mole app dirs + du per bundle — allow a few seconds.
	if elapsed > 8*time.Second {
		t.Fatalf("ScanQuick took %v (>8s)", elapsed)
	}
	if len(r.Apps) == 0 {
		t.Skip("no apps")
	}
	var nonzero int
	for _, a := range r.Apps {
		if a.AppBytes > 0 {
			nonzero++
		}
		if a.ByteSize != a.AppBytes {
			t.Fatalf("%s: byteSize should equal appBytes", a.Name)
		}
	}
	if nonzero == 0 {
		t.Fatal("all appBytes are 0")
	}
	t.Logf("ScanQuick %v apps=%d", elapsed, len(r.Apps))
}

func TestScanCompletesReasonably(t *testing.T) {
	start := time.Now()
	r := Scan()
	elapsed := time.Since(start)
	if elapsed > 45*time.Second {
		t.Fatalf("Scan took %v (>45s), apps=%d orphans=%d", elapsed, len(r.Apps), len(r.Orphans))
	}
	t.Logf("Scan %v apps=%d orphans=%d", elapsed, len(r.Apps), len(r.Orphans))
}

func TestLeftoverDuAccurate(t *testing.T) {
	p := fsutil.HomeDir() + "/Library/Application Support/Cursor"
	if !fsutil.Exists(p) {
		t.Skip("Cursor Application Support missing")
	}
	sz := sizeLeftover(p)
	du, ok := fsutil.DuBytes(p)
	if !ok {
		t.Fatal("du failed")
	}
	if sz != du {
		t.Fatalf("sizeLeftover %d != du %d", sz, du)
	}
	if sz < 1_000_000_000 {
		t.Fatalf("expected ~GB-scale leftover, got %d", sz)
	}
}

func TestCursorLeftoversAttached(t *testing.T) {
	r := Scan()
	var cursor *AppResult
	for i := range r.Apps {
		if r.Apps[i].Name == "Cursor" {
			cursor = &r.Apps[i]
			break
		}
	}
	if cursor == nil {
		t.Skip("Cursor not installed")
	}
	if cursor.LeftoverBytes < 1_000_000_000 {
		t.Fatalf("Cursor leftoverBytes %d — expected Mole-scale Application Support", cursor.LeftoverBytes)
	}
}
