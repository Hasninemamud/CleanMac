package fsutil

import (
	"os"
	"os/exec"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/Hasninemamud/CleanMac/internal/safety"
)

func TestPathSizeMatchesDuSkP(t *testing.T) {
	p := "/Applications/Cursor.app"
	if !Exists(p) {
		t.Skip("Cursor.app not installed")
	}
	got := PathSizeOpts(p, safety.Opts{AllowApps: true})
	out, err := exec.Command("/usr/bin/du", "-skP", p).Output()
	if err != nil {
		t.Fatal(err)
	}
	kb, err := strconv.ParseInt(strings.Fields(string(out))[0], 10, 64)
	if err != nil {
		t.Fatal(err)
	}
	want := kb * 1024
	if got == want {
		return
	}
	// mdls physical can differ slightly from du; never under-report by >5%.
	diff := got - want
	if diff < 0 {
		diff = -diff
	}
	if got < want && float64(diff) > float64(want)*0.05 {
		t.Fatalf("PathSize %d under-reports du -skP %d", got, want)
	}
}

func TestDuChildrenListsKids(t *testing.T) {
	dir := t.TempDir()
	a := dir + "/a"
	b := dir + "/b"
	if err := os.Mkdir(a, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(b, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a+"/f", make([]byte, 4096), 0o644); err != nil {
		t.Fatal(err)
	}
	got := DuChildren(dir, 5*time.Second)
	if got[a] <= 0 || got[b] < 0 {
		t.Fatalf("DuChildren=%v", got)
	}
}

func TestLeftoverDuParity(t *testing.T) {
	p := HomeDir() + "/Library/Application Support/Cursor"
	if !Exists(p) {
		t.Skip("Cursor Application Support missing")
	}
	got := PathSize(p)
	du, ok := DuBytes(p)
	if !ok {
		t.Fatal("du failed")
	}
	if got != du {
		t.Fatalf("PathSize %d != du %d", got, du)
	}
	if got < 1_000_000_000 {
		t.Fatalf("expected multi-GB Cursor leftover, got %d", got)
	}
}
