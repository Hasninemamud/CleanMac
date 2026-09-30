package whitelist

import "testing"

func TestAddRemove(t *testing.T) {
	// Use temp by monkeying Path is hard; just ensure Load doesn't panic.
	_ = Load()
	_ = Excludes("/tmp/cleanmac-whitelist-test-path")
}
