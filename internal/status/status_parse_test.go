package status

import (
	"strings"
	"testing"

	"github.com/Hasninemamud/CleanMac/internal/disk"
)

func TestCPUBusyFromTopOutput(t *testing.T) {
	out := `Processes: 500 total
CPU usage: 90.0% user, 5.0% sys, 5.0% idle
CPU usage: 11.62% user, 13.95% sys, 74.41% idle
`
	p, ok := cpuBusyFromTopOutput(out)
	if !ok {
		t.Fatal("expected ok")
	}
	want := 100 - 74.41
	if p < want-0.01 || p > want+0.01 {
		t.Fatalf("got %v want ~%v", p, want)
	}
}

func TestGPUUtilFromIoreg(t *testing.T) {
	s := `"PerformanceStatistics" = {"Renderer Utilization %"=12,"Device Utilization %"=38}`
	if v := gpuUtilFromIoreg(s); v != 38 {
		t.Fatalf("got %v want 38", v)
	}
	if v := gpuUtilFromIoreg("nope"); v != -1 {
		t.Fatalf("got %v want -1", v)
	}
}

func TestHealthModerateLoadNotStressed(t *testing.T) {
	vol := disk.Volume{Total: 245e9, Free: 95e9, Used: 150e9}
	score, label := health(48, 0.76, vol, 80, "AC", 20)
	if label == "Stressed" || score < 55 {
		t.Fatalf("score=%d label=%s; moderate load should not be Stressed", score, label)
	}
}

func TestMemoryFromVMStatMatchesActivityMonitor(t *testing.T) {
	vm := `Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                4000.
Pages active:                            200000.
Pages inactive:                          200000.
Pages speculative:                          300.
Pages wired down:                        120000.
Pages purgeable:                             50.
Anonymous pages:                         280000.
File-backed pages:                       130000.
Pages occupied by compressor:            480000.
`
	const total uint64 = 16 * 1024 * 1024 * 1024
	_, used, _, app, wired, comp, cached := memoryFromVMStat(vm, total)
	page := uint64(16384)
	wantApp := (uint64(280000) - 50) * page
	wantWired := uint64(120000) * page
	wantComp := uint64(480000) * page
	wantCached := uint64(130000) * page
	if app != wantApp || wired != wantWired || comp != wantComp || cached != wantCached {
		t.Fatalf("buckets app=%d wired=%d comp=%d cached=%d", app, wired, comp, cached)
	}
	if used != wantApp+wantWired+wantComp {
		t.Fatalf("used=%d want %d", used, wantApp+wantWired+wantComp)
	}
	// Must not use total−free−inactive (that inflated Mem % vs Activity Monitor).
	alt := total - (4000+300)*page - 200000*page
	if used == alt {
		t.Fatal("used unexpectedly equals alt total-free-inactive formula")
	}
}

func TestProcessNamePathAppBundle(t *testing.T) {
	name, path := processNamePath("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
	if name != "Google Chrome" {
		t.Fatalf("name=%q", name)
	}
	if path != "/Applications/Google Chrome.app" {
		t.Fatalf("path=%q", path)
	}
}

func TestParsePSLineKeepsSpaces(t *testing.T) {
	line := "62511  12.5  2.0  367001 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --flag"
	pid, cpu, _, rss, cmd, ok := parsePSLine(line)
	if !ok || pid != 62511 || cpu != 12.5 || rss != 367001 {
		t.Fatalf("pid=%d cpu=%v rss=%d ok=%v", pid, cpu, rss, ok)
	}
	if !strings.HasPrefix(cmd, "/Applications/Google Chrome.app/") {
		t.Fatalf("cmd=%q", cmd)
	}
}
