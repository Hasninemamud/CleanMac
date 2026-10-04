package apps

import (
	"testing"

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
	sz := sizeOf(p)
	if sz < 10_000_000 {
		t.Fatalf("expected real .app size, got %d", sz)
	}
	t.Logf("Cursor.app size=%d", sz)
}

func TestScanReturnsAppBytes(t *testing.T) {
	r := Scan()
	if len(r.Apps) == 0 {
		t.Skip("no apps")
	}
	var nonzero int
	for _, a := range r.Apps {
		if a.AppBytes > 0 {
			nonzero++
		}
		if a.ByteSize != a.AppBytes {
			t.Fatalf("%s: byteSize should equal appBytes (original bundle), got byte=%d app=%d", a.Name, a.ByteSize, a.AppBytes)
		}
	}
	if nonzero == 0 {
		t.Fatal("all appBytes are 0 — AllowApps sizing broken")
	}
}
