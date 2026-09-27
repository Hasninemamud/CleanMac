package disk

import "testing"

func TestParseParenBytes(t *testing.T) {
	n, ok := parseParenBytes("Container Total Space:     245.1 GB (245107195904 Bytes) (exactly 478724992 512-Byte-Units)")
	if !ok || n != 245107195904 {
		t.Fatalf("got %d ok=%v", n, ok)
	}
}

func TestVolumeUsageContainer(t *testing.T) {
	v := VolumeUsage("/")
	if v.Total < 100_000_000_000 {
		t.Fatalf("expected real disk total, got %+v", v)
	}
	if v.Used+v.Free != v.Total {
		t.Fatalf("used+free != total: %+v", v)
	}
	// Must not report sealed-system-only used (~18GB on a full Mac).
	if v.Total > 200_000_000_000 && v.Used < 30_000_000_000 && v.Free > 50_000_000_000 {
		// Allow empty-ish machines; only fail the classic snapshot bug (used≈18G with huge free).
		if v.Used > 0 && v.Used < 25_000_000_000 {
			t.Fatalf("used looks like APFS system snapshot only: %+v", v)
		}
	}
}
