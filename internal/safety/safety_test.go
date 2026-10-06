package safety

import "testing"

func TestBlockedSystem(t *testing.T) {
	for _, p := range []string{"/", "/System", "/System/Library", "/usr/bin", "/private", "/Applications/Safari.app"} {
		if !IsBlocked(p, Opts{}) {
			t.Fatalf("expected blocked: %s", p)
		}
	}
}

func TestAllowApps(t *testing.T) {
	p := "/Applications/Foo.app"
	if !IsBlocked(p, Opts{}) {
		t.Fatal("apps blocked by default")
	}
	if IsBlocked(p, Opts{AllowApps: true}) {
		t.Fatal("allowApps should permit")
	}
}

func TestHomeCacheOk(t *testing.T) {
	p := "/Users/test/Library/Caches/foo"
	if IsBlocked(p, Opts{}) {
		t.Fatal("user cache should not be blocked")
	}
	if Classify(p, "safe", Opts{}) != "safe" {
		t.Fatal("classify safe")
	}
}

func TestSensitiveHomeBlocked(t *testing.T) {
	for _, p := range []string{
		"/Users/test/Library/Keychains",
		"/Users/test/Library/Caches/CloudKit",
		"/Users/test/Library/Caches/CloudKit/foo",
		"/Users/test/Pictures/Photos Library.photoslibrary/data",
	} {
		if !IsBlocked(p, Opts{}) {
			t.Fatalf("expected blocked: %s", p)
		}
	}
}

func TestPermanentDeleteJunkOnly(t *testing.T) {
	// Clean / Apps caches / AI → permanent; uninstall + Analyze → Trash.
	if !PermanentDelete(false, false) {
		t.Fatal("junk cleanup should permanently delete")
	}
	if PermanentDelete(true, false) {
		t.Fatal("uninstall must keep Trash")
	}
	if PermanentDelete(false, true) {
		t.Fatal("Analyze must keep Trash")
	}
	if PermanentDelete(true, true) {
		t.Fatal("uninstall+analyze must keep Trash")
	}
}
