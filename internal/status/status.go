package status

import (
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/Hasninemamud/CleanMac/internal/disk"
	"github.com/Hasninemamud/CleanMac/internal/fsutil"
)

type Snapshot struct {
	Timestamp   int64   `json:"timestamp"`
	Hostname    string  `json:"hostname"`
	GOOS        string  `json:"goos"`
	GOARCH      string  `json:"goarch"`
	NumCPU      int     `json:"numCPU"`
	LoadAvg     []float64 `json:"loadAvg,omitempty"`
	MemTotal    uint64  `json:"memTotal"`
	MemUsed     uint64  `json:"memUsed"`
	MemFree     uint64  `json:"memFree"`
	DiskTotal   int64   `json:"diskTotal"`
	DiskFree    int64   `json:"diskFree"`
	DiskUsed    int64   `json:"diskUsed"`
	UptimeSec   int64   `json:"uptimeSec,omitempty"`
}

func Collect() Snapshot {
	host, _ := os.Hostname()
	vol := disk.VolumeUsage(fsutil.HomeDir())
	memTotal, memUsed, memFree := memory()
	return Snapshot{
		Timestamp: time.Now().Unix(),
		Hostname:  host,
		GOOS:      runtime.GOOS,
		GOARCH:    runtime.GOARCH,
		NumCPU:    runtime.NumCPU(),
		LoadAvg:   loadAvg(),
		MemTotal:  memTotal,
		MemUsed:   memUsed,
		MemFree:   memFree,
		DiskTotal: vol.Total,
		DiskFree:  vol.Free,
		DiskUsed:  vol.Used,
		UptimeSec: uptime(),
	}
}

func memory() (total, used, free uint64) {
	// sysctl hw.memsize + vm_stat page counts (no gopsutil dep — keep lean)
	out, err := exec.Command("sysctl", "-n", "hw.memsize").Output()
	if err == nil {
		if n, e := strconv.ParseUint(strings.TrimSpace(string(out)), 10, 64); e == nil {
			total = n
		}
	}
	vm, err := exec.Command("vm_stat").Output()
	if err != nil {
		return total, 0, 0
	}
	pageSize := uint64(4096)
	var freePages, inactive, speculative uint64
	for _, line := range strings.Split(string(vm), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "page size of") {
			fields := strings.Fields(line)
			if len(fields) >= 4 {
				if n, e := strconv.ParseUint(fields[3], 10, 64); e == nil {
					pageSize = n
				}
			}
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		val := strings.TrimSpace(strings.TrimSuffix(parts[1], "."))
		n, _ := strconv.ParseUint(val, 10, 64)
		switch parts[0] {
		case "Pages free":
			freePages = n
		case "Pages inactive":
			inactive = n
		case "Pages speculative":
			speculative = n
		}
	}
	free = (freePages + inactive + speculative) * pageSize
	if total > free {
		used = total - free
	}
	return
}

func loadAvg() []float64 {
	out, err := exec.Command("sysctl", "-n", "vm.loadavg").Output()
	if err != nil {
		return nil
	}
	// { 1.2 1.1 1.0 }
	s := strings.Trim(strings.TrimSpace(string(out)), "{}")
	fields := strings.Fields(s)
	var avg []float64
	for _, f := range fields {
		if v, e := strconv.ParseFloat(f, 64); e == nil {
			avg = append(avg, v)
		}
	}
	return avg
}

func uptime() int64 {
	out, err := exec.Command("sysctl", "-n", "kern.boottime").Output()
	if err != nil {
		return 0
	}
	// { sec = 123, usec = 0 } ...
	s := string(out)
	i := strings.Index(s, "sec = ")
	if i < 0 {
		return 0
	}
	rest := s[i+6:]
	end := strings.IndexAny(rest, ",}")
	if end < 0 {
		return 0
	}
	sec, err := strconv.ParseInt(strings.TrimSpace(rest[:end]), 10, 64)
	if err != nil {
		return 0
	}
	return time.Now().Unix() - sec
}
