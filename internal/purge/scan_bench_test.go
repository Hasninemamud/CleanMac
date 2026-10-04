package purge

import (
	"testing"
	"time"
)

func TestScanCompletesQuickly(t *testing.T) {
	start := time.Now()
	items := Scan(nil)
	elapsed := time.Since(start)
	if elapsed > 2*time.Second {
		t.Fatalf("purge Scan took %v (>2s), items=%d", elapsed, len(items))
	}
	t.Logf("purge Scan %v items=%d", elapsed, len(items))
}
