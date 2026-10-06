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
	cpuPct := cpuPercentRealtime(load, runtime.NumCPU())
	pressure := memPressure(memUsed, memTotal, swap)
	battPct, battState, battW := battery()
	// Warm the net sampler so the first popover open has a real rate.
	_, _ = networkKBs()
	time.Sleep(220 * time.Millisecond)
	down, up := networkKBs()
	procs := topProcesses(12)
	gpu := gpuUtilization()
	if gpu < 0 {
		gpu = gpuEstimate(procs)
	}
	uptimeSec := uptime()
	score, label := health(cpuPct, pressure, vol, battPct, battState, gpu)

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
	return memoryFromVMStat(string(vm), total)
}

// memoryFromVMStat matches Activity Monitor / Stats: App = anonymous−purgeable,
// Memory Used = App + Wired + Compressed. File-backed pages are Cached (not Used).
func memoryFromVMStat(vm string, total uint64) (tot, used, free, app, wired, compressed, cached uint64) {
	tot = total
	pageSize := uint64(4096)
	var freePages, speculative, wiredPages, compressedPages uint64
	var anonymous, purgeable, fileBacked, active, inactive uint64
	for _, line := range strings.Split(vm, "\n") {
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
		case "Pages purgeable":
			purgeable = n
		case "Anonymous pages":
			anonymous = n
		case "File-backed pages":
			fileBacked = n
		}
	}
	// Activity Monitor App Memory ≈ internal/anonymous − purgeable.
	if anonymous > 0 {
		if anonymous > purgeable {
			app = (anonymous - purgeable) * pageSize
		}
	} else {
		// Older vm_stat without Anonymous pages.
		app = active * pageSize
	}
	wired = wiredPages * pageSize
	compressed = compressedPages * pageSize
	if fileBacked > 0 {
		cached = fileBacked * pageSize
	} else {
		cached = inactive * pageSize
	}
	free = (freePages + speculative) * pageSize
	used = app + wired + compressed
	if tot > 0 && used > tot {
		used = tot
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
	// Match Activity Monitor Memory Used % — swap is reported separately.
	_ = swap
	p := float64(used) / float64(total)
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
	return cpuPercentRealtime(load, cores)
}

// cpuPercentRealtime prefers `top` idle samples (matches Activity Monitor),
// falling back to 1-minute load average / cores.
func cpuPercentRealtime(load []float64, cores int) float64 {
	if p, ok := cpuPercentFromTop(); ok {
		return p
	}
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

func cpuPercentFromTop() (float64, bool) {
	// -s 1: second sample is a real 1s interval (Activity Monitor style).
	// -s 0 yields no usable idle line → we'd fall back to loadavg (wrong).
	out, err := exec.Command("top", "-l", "2", "-n", "0", "-s", "1").Output()
	if err != nil {
		return 0, false
	}
	return cpuBusyFromTopOutput(string(out))
}

// cpuBusyFromTopOutput uses the last "CPU usage: … % idle" line (interval sample).
func cpuBusyFromTopOutput(s string) (float64, bool) {
	var idle float64
	found := false
	for _, line := range strings.Split(s, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "CPU usage:") {
			continue
		}
		// CPU usage: 11.62% user, 13.95% sys, 74.41% idle
		if i := strings.Index(line, "% idle"); i > 0 {
			start := strings.LastIndex(line[:i], " ")
			if start < 0 {
				continue
			}
			num := strings.TrimSpace(line[start:i])
			if v, e := strconv.ParseFloat(num, 64); e == nil {
				idle = v
				found = true
			}
		}
	}
	if !found {
		return 0, false
	}
	p := 100 - idle
	if p < 0 {
		p = 0
	}
	if p > 100 {
		p = 100
	}
	return p, true
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
		pid, cpu, memPct, rssKB, cmd, ok := parsePSLine(line)
		if !ok {
			continue
		}
		name, path := processNamePath(cmd)
		if name == "" || name == "ps" {
			continue
		}
		// ps/top %CPU is per-core (can exceed system-wide %); same scale as Activity Monitor.
		rows = append(rows, row{
			ProcessRow: ProcessRow{PID: pid, Name: name, Path: path, CPU: cpu, MemPct: memPct, MemMB: float64(rssKB) / 1024},
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

// parsePSLine splits "pid pcpu pmem rss command…" without breaking paths that contain spaces.
func parsePSLine(line string) (pid int, cpu, memPct float64, rssKB int64, cmd string, ok bool) {
	fields := strings.Fields(line)
	if len(fields) < 5 {
		return 0, 0, 0, 0, "", false
	}
	pid, err1 := strconv.Atoi(fields[0])
	cpu, err2 := strconv.ParseFloat(fields[1], 64)
	memPct, err3 := strconv.ParseFloat(fields[2], 64)
	rssKB, err4 := strconv.ParseInt(fields[3], 10, 64)
	if err1 != nil || err2 != nil || err3 != nil || err4 != nil {
		return 0, 0, 0, 0, "", false
	}
	// Skip the first four fields in the original line to keep "Google Chrome.app/…".
	s := strings.TrimSpace(line)
	for n := 0; n < 4; n++ {
		sp := strings.IndexAny(s, " \t")
		if sp < 0 {
			return 0, 0, 0, 0, "", false
		}
		s = strings.TrimLeft(s[sp:], " \t")
	}
	if s == "" {
		return 0, 0, 0, 0, "", false
	}
	return pid, cpu, memPct, rssKB, s, true
}

func processNamePath(cmd string) (name, path string) {
	cmd = strings.TrimSpace(cmd)
	if cmd == "" {
		return "", ""
	}
	if i := strings.Index(cmd, ".app/"); i >= 0 {
		bundle := cmd[:i+4]
		path = bundle
		if slash := strings.LastIndex(bundle, "/"); slash >= 0 {
			name = bundle[slash+1 : len(bundle)-4] // strip .app
		} else {
			name = bundle[:len(bundle)-4]
		}
		if name == "" {
			name = bundle
		}
		return name, path
	}
	fields := strings.Fields(cmd)
	path = fields[0]
	name = path
	if slash := strings.LastIndex(name, "/"); slash >= 0 {
		name = name[slash+1:]
	}
	return name, path
}

func gpuUtilization() float64 {
	out, err := exec.Command("ioreg", "-r", "-d", "1", "-w", "0", "-c", "IOAccelerator").Output()
	if err != nil {
		return -1
	}
	return gpuUtilFromIoreg(string(out))
}

// gpuUtilFromIoreg picks the max "Device Utilization %" from IOAccelerator trees.
func gpuUtilFromIoreg(s string) float64 {
	best := -1.0
	needle := `"Device Utilization %"=`
	for {
		i := strings.Index(s, needle)
		if i < 0 {
			break
		}
		rest := s[i+len(needle):]
		end := 0
		for end < len(rest) && ((rest[end] >= '0' && rest[end] <= '9') || rest[end] == '.') {
			end++
		}
		if end > 0 {
			if v, e := strconv.ParseFloat(rest[:end], 64); e == nil && v > best {
				best = v
			}
		}
		s = rest
	}
	if best < 0 {
		return -1
	}
	if best > 100 {
		best = 100
	}
	return best
}

func gpuEstimate(procs []ProcessRow) float64 {
	// Last-resort only — WindowServer CPU is not GPU utilization.
	var sum float64
	for _, p := range procs {
		n := strings.ToLower(p.Name)
		if strings.Contains(n, "windowserver") || strings.Contains(n, "metal") || strings.HasPrefix(n, "gpu") {
			sum += p.CPU * 0.35
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

func health(cpuPct, pressure float64, vol disk.Volume, batt int, battState string, gpuPct float64) (int, string) {
	// Mole-ish: plentiful free disk + moderate CPU/GPU stay Good; only heavy
	// memory pressure (not mid 70s used%) should drag into Fair/Stressed.
	score := 100.0
	score -= clamp01(cpuPct/100) * 20
	score -= clamp01(gpuPct/100) * 8
	// Ignore used% until ~65%; ramp to full weight near 100%.
	score -= clamp01((pressure-0.65)/0.35) * 22
	if vol.Total > 0 {
		freePct := float64(vol.Free) / float64(vol.Total)
		if freePct < 0.12 {
			score -= (0.12 - freePct) * 80
		} else if freePct < 0.20 {
			score -= (0.20 - freePct) * 25
		}
	}
	if batt > 0 && batt < 15 && battState != "Charging" && battState != "Charged" && battState != "AC" {
		score -= 8
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
	case s >= 88:
		label = "Excellent"
	case s >= 72:
		label = "Good"
	case s >= 55:
		label = "Fair"
	default:
		label = "Stressed"
	}
	return s, label
}

func clamp01(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}
