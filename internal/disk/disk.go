package disk

import (
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/safety"
)

type Volume struct {
	Total int64 `json:"total"`
	Free  int64 `json:"free"`
	Used  int64 `json:"used"`
}

type Overview struct {
	TotalBytes    int64            `json:"totalBytes"`
	FreeBytes     int64            `json:"freeBytes"`
	UsedBytes     int64            `json:"usedBytes"`
	CategoryBytes map[string]int64 `json:"categoryBytes"`
	TopFolders    []Folder         `json:"topFolders"`
}

type Folder struct {
	Path        string `json:"path"`
	Name        string `json:"name"`
	ByteSize    int64  `json:"byteSize"`
	IsDirectory bool   `json:"isDirectory"`
}

func VolumeUsage(mount string) Volume {
	if mount == "" {
		mount = "/"
	}
	if v, ok := volumeFromDiskutil(mount); ok {
		return v
	}
	// Sealed system volume: try Data / root for container totals.
	if mount != "/" {
		if v, ok := volumeFromDiskutil("/"); ok {
			return v
		}
	}
	return volumeFromDF(mount)
}

// volumeFromDiskutil reads APFS container totals (matches System Settings Storage).
// df's "Used" on / is only the sealed snapshot (~18GB), not container used.
func volumeFromDiskutil(mount string) (Volume, bool) {
	out, err := exec.Command("diskutil", "info", mount).Output()
	if err != nil {
		return Volume{}, false
	}
	var total, free int64
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(line, "Container Total Space:"):
			if n, ok := parseParenBytes(line); ok {
				total = n
			}
		case strings.HasPrefix(line, "Container Free Space:"):
			if n, ok := parseParenBytes(line); ok {
				free = n
			}
		case total == 0 && strings.HasPrefix(line, "Disk Size:"):
			if n, ok := parseParenBytes(line); ok {
				total = n
			}
		}
	}
	if total <= 0 {
		return Volume{}, false
	}
	if free < 0 {
		free = 0
	}
	if free > total {
		free = total
	}
	return Volume{Total: total, Free: free, Used: total - free}, true
}

func parseParenBytes(line string) (int64, bool) {
	i := strings.Index(line, "(")
	j := strings.Index(line, " Bytes)")
	if i < 0 || j <= i {
		return 0, false
	}
	n, err := strconv.ParseInt(strings.TrimSpace(line[i+1:j]), 10, 64)
	return n, err == nil && n > 0
}

func volumeFromDF(mount string) Volume {
	out, err := exec.Command("df", "-k", mount).Output()
	if err != nil {
		return Volume{}
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) < 2 {
		return Volume{}
	}
	parts := strings.Fields(lines[1])
	if len(parts) < 4 {
		return Volume{}
	}
	totalK, _ := strconv.ParseInt(parts[1], 10, 64)
	availK, _ := strconv.ParseInt(parts[3], 10, 64)
	total := totalK * 1024
	free := availK * 1024
	// Use total−free: df "Used" on APFS system snapshot is not container used.
	return Volume{Total: total, Free: free, Used: total - free}
}

func classifyHomeItem(name string) string {
	n := strings.ToLower(name)
	if n == "documents" || n == "desktop" || n == "downloads" {
		return "documents"
	}
	if n == "library" {
		return "caches"
	}
	if n == "applications" || strings.HasSuffix(n, ".app") {
		return "apps"
	}
	return "other"
}

func ScanOverview(onProgress func(int, string)) Overview {
	home := fsutil.HomeDir()
	vol := VolumeUsage(home)
	categoryBytes := map[string]int64{"apps": 0, "documents": 0, "caches": 0, "other": 0}

	type job struct {
		full, name, cat string
		isDir           bool
		fileSize        int64
	}
	var jobs []job
	entries, _ := os.ReadDir(home)
	for _, ent := range entries {
		if strings.HasPrefix(ent.Name(), ".") {
			continue
		}
		full := filepath.Join(home, ent.Name())
		typ := ent.Type()
		if typ&os.ModeSymlink != 0 || safety.IsBlocked(full, safety.Opts{}) {
			continue
		}
		if ent.IsDir() {
			jobs = append(jobs, job{full: full, name: ent.Name(), cat: classifyHomeItem(ent.Name()), isDir: true})
			continue
		}
		if !typ.IsRegular() {
			continue
		}
		info, err := ent.Info()
		if err != nil {
			continue
		}
		jobs = append(jobs, job{full: full, name: ent.Name(), cat: classifyHomeItem(ent.Name()), fileSize: info.Size()})
	}
	if fsutil.Exists("/Applications") {
		jobs = append(jobs, job{full: "/Applications", name: "Applications", cat: "apps", isDir: true})
	}

	topFolders := make([]Folder, len(jobs))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)
	var mu sync.Mutex
	for i, j := range jobs {
		wg.Add(1)
		go func(i int, j job) {
			defer wg.Done()
			size := j.fileSize
			if j.isDir {
				sem <- struct{}{}
				// Timed du — overview must not block the Analyze UI on huge folders.
				size = fsutil.PathSizeQuick(j.full)
				<-sem
			}
			if onProgress != nil {
				onProgress(i+1, j.full)
			}
			topFolders[i] = Folder{Path: j.full, Name: j.name, ByteSize: size, IsDirectory: j.isDir}
			mu.Lock()
			categoryBytes[j.cat] += size
			mu.Unlock()
		}(i, j)
	}
	wg.Wait()

	compact := topFolders[:0]
	for _, f := range topFolders {
		if f.ByteSize > 0 {
			compact = append(compact, f)
		}
	}
	topFolders = compact
	sort.Slice(topFolders, func(i, j int) bool { return topFolders[i].ByteSize > topFolders[j].ByteSize })
	if len(topFolders) > 30 {
		topFolders = topFolders[:30]
	}
	return Overview{
		TotalBytes: vol.Total, FreeBytes: vol.Free, UsedBytes: vol.Used,
		CategoryBytes: categoryBytes, TopFolders: topFolders,
	}
}

func CollectLarge(root string, minBytes int64, maxFiles int, onProgress func(int, string)) []jsonout.Item {
	if minBytes <= 0 {
		minBytes = 50 * 1024 * 1024
	}
	if maxFiles <= 0 {
		maxFiles = 5000
	}
	var items []jsonout.Item
	visited := 0
	stack := []string{root}
	for len(stack) > 0 && len(items) < maxFiles {
		current := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if safety.IsBlocked(current, safety.Opts{}) {
			continue
		}
		entries, err := os.ReadDir(current)
		if err != nil {
			continue
		}
		for _, ent := range entries {
			full := filepath.Join(current, ent.Name())
			info, err := ent.Info()
			if err != nil || safety.IsBlocked(full, safety.Opts{}) || info.Mode()&os.ModeSymlink != 0 {
				continue
			}
			visited++
			if visited%200 == 0 && onProgress != nil {
				onProgress(visited, full)
			}
			if ent.IsDir() {
				if strings.HasSuffix(ent.Name(), ".app") || strings.HasSuffix(ent.Name(), ".framework") {
					continue
				}
				stack = append(stack, full)
			} else if info.Mode().IsRegular() {
				sz := fsutil.PathSize(full)
				if sz < minBytes {
					continue
				}
				s := safety.Classify(full, "review", safety.Opts{})
				if s == "blocked" {
					continue
				}
				items = append(items, jsonout.Item{
					Path: full, Name: ent.Name(), ByteSize: sz, Safety: s,
					Category: "other", Explanation: "Large file",
					ModifiedAt: float64(info.ModTime().UnixMilli()),
				})
				if len(items) >= maxFiles {
					break
				}
			}
		}
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ByteSize > items[j].ByteSize })
	return items
}
