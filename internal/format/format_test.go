package format

import "testing"

func TestDiskBytesMatchesMacOSStyle(t *testing.T) {
	// 245.1 GB container (decimal) must not show as ~228 GiB.
	const total int64 = 245107195904
	got := DiskBytes(total)
	if got != "245 GB" {
		t.Fatalf("DiskBytes(%d) = %q, want 245 GB", total, got)
	}
	bin := Bytes(total)
	if bin == "245 GB" {
		t.Fatalf("Bytes should use binary units, got %q", bin)
	}
}
