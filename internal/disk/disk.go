package disk

import (
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

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
	usedK, _ := strconv.ParseInt(parts[2], 10, 64)
	availK, _ := strconv.ParseInt(parts[3], 10, 64)
	return Volume{Total: totalK * 1024, Free: availK * 1024, Used: usedK * 1024}
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
	var topFolders []Folder
	visited := 0

	entries, _ := os.ReadDir(home)
	for _, ent := range entries {
		if strings.HasPrefix(ent.Name(), ".") {
			continue
		}
		full := filepath.Join(home, ent.Name())
		info, err := ent.Info()
		if err != nil || safety.IsBlocked(full, safety.Opts{}) || info.Mode()&os.ModeSymlink != 0 {
			continue
		}
		visited++
		if onProgress != nil {
			onProgress(visited, full)
		}
		var size int64
		if ent.IsDir() {
			size = fsutil.ShallowFolderSize(full)
		} else if info.Mode().IsRegular() {
			size = info.Size()
		}
		cat := classifyHomeItem(ent.Name())
		categoryBytes[cat] += size
		topFolders = append(topFolders, Folder{Path: full, Name: ent.Name(), ByteSize: size, IsDirectory: ent.IsDir()})
	}

	apps := "/Applications"
	if fsutil.Exists(apps) {
		appsSize := fsutil.ShallowFolderSize(apps)
		categoryBytes["apps"] += appsSize
		topFolders = append(topFolders, Folder{Path: apps, Name: "Applications", ByteSize: appsSize, IsDirectory: true})
	}
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
				if info.Size() < minBytes {
					continue
				}
				s := safety.Classify(full, "review", safety.Opts{})
				if s == "blocked" {
					continue
				}
				items = append(items, jsonout.Item{
					Path: full, Name: ent.Name(), ByteSize: info.Size(), Safety: s,
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
