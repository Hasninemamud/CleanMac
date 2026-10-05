package status

import (
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Hasninemamud/CleanMac/internal/disk"
)

type ProcessRow struct {
	PID     int     `json:"pid"`
	Name    string  `json:"name"`
	Path    string  `json:"path,omitempty"`
	CPU     float64 `json:"cpu"`
	MemMB   float64 `json:"memMB"`
	MemPct  float64 `json:"memPct"`
}

type Snapshot struct {
	Timestamp   int64        `json:"timestamp"`
	Hostname    string       `json:"hostname"`
	GOOS        string       `json:"goos"`
	GOARCH      string       `json:"goarch"`
	Model       string       `json:"model,omitempty"`
	Chip        string       `json:"chip,omitempty"`
	OSVersion   string       `json:"osVersion,omitempty"`
	NumCPU      int          `json:"numCPU"`
	LoadAvg     []float64    `json:"loadAvg,omitempty"`
	CPUPercent  float64      `json:"cpuPercent"`
	MemTotal    uint64       `json:"memTotal"`
	MemUsed     uint64       `json:"memUsed"`
	MemFree     uint64       `json:"memFree"`
	MemPressure float64      `json:"memPressure"`
	SwapUsed    uint64       `json:"swapUsed"`
	MemApp      uint64       `json:"memApp"`
	MemWired    uint64       `json:"memWired"`
	MemCompressed uint64     `json:"memCompressed"`
	MemCached   uint64       `json:"memCached"`
	DiskTotal   int64        `json:"diskTotal"`
	DiskFree    int64        `json:"diskFree"`
	DiskUsed    int64        `json:"diskUsed"`
	UptimeSec   int64        `json:"uptimeSec,omitempty"`
	BatteryPct  int          `json:"batteryPct"`
	BatteryState string      `json:"batteryState,omitempty"`
	BatteryWatts float64     `json:"batteryWatts,omitempty"`
	BatteryCycles int        `json:"batteryCycles,omitempty"`
	NetDownKBs  float64      `json:"netDownKBs"`
	NetUpKBs    float64      `json:"netUpKBs"`
	GPUPercent  float64      `json:"gpuPercent"`
	Thermal     string       `json:"thermal,omitempty"`
	HealthScore int          `json:"healthScore"`
	HealthLabel string       `json:"healthLabel"`
	Processes   []ProcessRow `json:"processes,omitempty"`
}

var (
	netMu      sync.Mutex
	lastNetIn  uint64
	lastNetOut uint64
	lastNetAt  time.Time
)

func Collect() Snapshot {
	host, _ := os.Hostname()
	vol := disk.VolumeUsage("/")
	memTotal, memUsed, memFree, memApp, memWired, memComp, memCached := memory()
	swap := swapUsed()
	load := loadAvg()
	cpuPct := cpuPercent(load, runtime.NumCPU())
	pressure := memPressure(memUsed, memTotal, swap)
	battPct, battState, battW := battery()
	down, up := networkKBs()
	procs := topProcesses(12)
	gpu := gpuEstimate(procs)
	uptimeSec := uptime()
	score, label := health(cpuPct, pressure, vol, battPct, battState)

	return Snapshot{
		Timestamp:     time.Now().Unix(),
		Hostname:      host,
		GOOS:          runtime.GOOS,
		GOARCH:        runtime.GOARCH,
		Model:         sysctl("hw.model"),
		Chip:          chipLabel(),
		OSVersion:     osVersion(),
		NumCPU:        runtime.NumCPU(),
		LoadAvg:       load,
		CPUPercent:    cpuPct,
		MemTotal:      memTotal,
		MemUsed:       memUsed,
		MemFree:       memFree,
		MemPressure:   pressure,
		SwapUsed:      swap,
		MemApp:        memApp,
		MemWired:      memWired,
		MemCompressed: memComp,
		MemCached:     memCached,
		DiskTotal:     vol.Total,
		DiskFree:      vol.Free,
		DiskUsed:      vol.Used,
		UptimeSec:     uptimeSec,
		BatteryPct:    battPct,
		BatteryState:  battState,
		BatteryWatts:  battW,
		NetDownKBs:    down,
		NetUpKBs:      up,
		GPUPercent:    gpu,
		Thermal:       thermalLabel(cpuPct, pressure),
		HealthScore:   score,
		HealthLabel:   label,
		Processes:     procs,
	}
}

func chipLabel() string {
	brand := sysctl("machdep.cpu.brand_string")
	if brand != "" {
		return brand
	}
	if runtime.GOARCH == "arm64" {
		return "Apple Silicon"
	}
	return runtime.GOARCH
}

func osVersion() string {
	out, err := exec.Command("sw_vers", "-productVersion").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func sysctl(key string) string {
	out, err := exec.Command("sysctl", "-n", key).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func memory() (total, used, free, app, wired, compressed, cached uint64) {
	out, err := exec.Command("sysctl", "-n", "hw.memsize").Output()
	if err == nil {
		if n, e := strconv.ParseUint(strings.TrimSpace(string(out)), 10, 64); e == nil {
			total = n
		}
	}
	vm, err := exec.Command("vm_stat").Output()
	if err != nil {
		return total, 0, 0, 0, 0, 0, 0
	}
	pageSize := uint64(4096)
	var freePages, inactive, speculative, active, wiredPages, compressedPages uint64
	for _, line := range strings.Split(string(vm), "\n") {
		line = strings.TrimSpace(line)
		// Header is "Mach Virtual Memory Statistics: (page size of 16384 bytes)".
		if i := strings.Index(line, "page size of "); i >= 0 {
			rest := line[i+len("page size of "):]
			fields := strings.Fields(rest)
			if len(fields) >= 1 {
				if n, e := strconv.ParseUint(fields[0], 10, 64); e == nil && n > 0 {
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
		case "Pages active":
			active = n
		case "Pages wired down", "Pages wired":
			wiredPages = n
		case "Pages occupied by compressor":
			compressedPages = n
		}
	}
	app = active * pageSize
	wired = wiredPages * pageSize
	compressed = compressedPages * pageSize
	cached = inactive * pageSize
	free = (freePages + speculative) * pageSize
	used = app + wired + compressed
	if total > free+cached {
		alt := total - free - cached
		if used == 0 || alt > used {
			used = alt
		}
	}
	if total > 0 && used > total {
		used = total
	}
	return
}

func swapUsed() uint64 {
	out, err := exec.Command("sysctl", "-n", "vm.swapusage").Output()
	if err != nil {
		return 0
	}
	// "total = 2048.00M  used = 412.50M  free = 1635.50M ..."
	s := string(out)
	i := strings.Index(s, "used = ")
	if i < 0 {
		return 0
	}
	rest := strings.TrimSpace(s[i+7:])
	end := strings.IndexAny(rest, " \t")
	if end > 0 {
		rest = rest[:end]
	}
	return parseMemSize(rest)
}

func parseMemSize(s string) uint64 {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}
	mult := float64(1)
	upper := strings.ToUpper(s)
	switch {
	case strings.HasSuffix(upper, "G"):
		mult = 1024 * 1024 * 1024
		s = s[:len(s)-1]
	case strings.HasSuffix(upper, "M"):
		mult = 1024 * 1024
		s = s[:len(s)-1]
	case strings.HasSuffix(upper, "K"):
		mult = 1024
		s = s[:len(s)-1]
	}
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0
	}
	return uint64(v * mult)
}

func memPressure(used, total, swap uint64) float64 {
	if total == 0 {
		return 0
	}
	p := float64(used) / float64(total)
	if swap > 0 {
		p += float64(swap) / float64(total) * 0.35
	}
	if p > 1 {
		p = 1
	}
	return p
}

func loadAvg() []float64 {
	out, err := exec.Command("sysctl", "-n", "vm.loadavg").Output()
	if err != nil {
		return nil
	}
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

func cpuPercent(load []float64, cores int) float64 {
	if cores < 1 {
		cores = 1
	}
	if len(load) == 0 {
		return 0
	}
	p := load[0] / float64(cores) * 100
	if p > 100 {
		p = 100
	}
	if p < 0 {
		p = 0
	}
	return p
}

func uptime() int64 {
	out, err := exec.Command("sysctl", "-n", "kern.boottime").Output()
	if err != nil {
		return 0
	}
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

func battery() (pct int, state string, watts float64) {
	out, err := exec.Command("pmset", "-g", "batt").Output()
	if err != nil {
		return 0, "Unknown", 0
	}
	s := string(out)
	if !strings.Contains(s, "%") {
		return 0, "Desktop", 0
	}
	state = "Battery"
	if strings.Contains(strings.ToLower(s), "charging") {
		state = "Charging"
	} else if strings.Contains(strings.ToLower(s), "charged") {
		state = "Charged"
	} else if strings.Contains(strings.ToLower(s), "ac power") {
		state = "AC"
	}
	// "-InternalBattery-0 (id=…)	87%; charging; ..."
	for _, part := range strings.Fields(s) {
		if strings.HasSuffix(part, "%;") || strings.HasSuffix(part, "%") {
			num := strings.TrimSuffix(strings.TrimSuffix(part, ";"), "%")
			if n, e := strconv.Atoi(num); e == nil {
				pct = n
				break
			}
		}
	}
	return pct, state, 0
}

func networkKBs() (down, up float64) {
	out, err := exec.Command("netstat", "-ib").Output()
	if err != nil {
		return 0, 0
	}
	var inB, outB uint64
	lines := strings.Split(string(out), "\n")
	for _, line := range lines[1:] {
		fields := strings.Fields(line)
		if len(fields) < 10 {
			continue
		}
		name := fields[0]
		if name == "lo0" || strings.HasPrefix(name, "awdl") || strings.HasPrefix(name, "llw") {
			continue
		}
		// Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes ...
		ib, _ := strconv.ParseUint(fields[6], 10, 64)
		ob, _ := strconv.ParseUint(fields[9], 10, 64)
		inB += ib
		outB += ob
	}

	now := time.Now()
	netMu.Lock()
	defer netMu.Unlock()
	if !lastNetAt.IsZero() {
		dt := now.Sub(lastNetAt).Seconds()
		if dt > 0.2 {
			if inB >= lastNetIn {
				down = float64(inB-lastNetIn) / dt / 1024
			}
			if outB >= lastNetOut {
				up = float64(outB-lastNetOut) / dt / 1024
			}
		}
	}
	lastNetIn, lastNetOut, lastNetAt = inB, outB, now
	return
}

func topProcesses(limit int) []ProcessRow {
	out, err := exec.Command("ps", "-axo", "pid=,pcpu=,pmem=,rss=,command=").Output()
	if err != nil {
		return nil
	}
	type row struct {
		ProcessRow
		rss int64
	}
	var rows []row
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 5 {
			continue
		}
		pid, _ := strconv.Atoi(fields[0])
		cpu, _ := strconv.ParseFloat(fields[1], 64)
		memPct, _ := strconv.ParseFloat(fields[2], 64)
		rssKB, _ := strconv.ParseInt(fields[3], 10, 64)
		exe := fields[4]
		name := exe
		if i := strings.LastIndex(name, "/"); i >= 0 {
			name = name[i+1:]
		}
		if name == "" || name == "ps" {
			continue
		}
		rows = append(rows, row{
			ProcessRow: ProcessRow{PID: pid, Name: name, Path: exe, CPU: cpu, MemPct: memPct, MemMB: float64(rssKB) / 1024},
			rss:        rssKB,
		})
	}
	// sort by CPU desc
	for i := 0; i < len(rows); i++ {
		for j := i + 1; j < len(rows); j++ {
			if rows[j].CPU > rows[i].CPU {
				rows[i], rows[j] = rows[j], rows[i]
			}
		}
	}
	if limit > len(rows) {
		limit = len(rows)
	}
	outRows := make([]ProcessRow, 0, limit)
	for i := 0; i < limit; i++ {
		outRows = append(outRows, rows[i].ProcessRow)
	}
	return outRows
}

func gpuEstimate(procs []ProcessRow) float64 {
	// ponytail: no private GPU API — approximate from WindowServer / GPU-ish process share
	var sum float64
	for _, p := range procs {
		n := strings.ToLower(p.Name)
		if strings.Contains(n, "windowserver") || strings.Contains(n, "metal") || strings.Contains(n, "gpu") {
			sum += p.CPU
		}
	}
	if sum > 100 {
		sum = 100
	}
	return sum
}

func thermalLabel(cpuPct, pressure float64) string {
	if cpuPct > 85 || pressure > 0.9 {
		return "Warm"
	}
	if cpuPct > 65 || pressure > 0.75 {
		return "Elevated"
	}
	return "Normal"
}

func health(cpuPct, pressure float64, vol disk.Volume, batt int, battState string) (int, string) {
	score := 100.0
	score -= cpuPct * 0.25
	score -= pressure * 40
	if vol.Total > 0 {
		diskPct := float64(vol.Used) / float64(vol.Total)
		score -= diskPct * 20
	}
	if batt > 0 && batt < 20 && battState != "Charging" && battState != "Charged" {
		score -= 10
	}
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	s := int(score + 0.5)
	label := "Good"
	switch {
	case s >= 90:
		label = "Excellent"
	case s >= 75:
		label = "Good"
	case s >= 55:
		label = "Fair"
	default:
		label = "Stressed"
	}
	return s, label
}
