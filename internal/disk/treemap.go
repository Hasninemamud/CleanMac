package disk

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/safety"
	"github.com/Hasninemamud/CleanMac/internal/whitelist"
)

// TreeNode is one folder/file in a drill-down disk map.
type TreeNode struct {
	Path        string     `json:"path"`
	Name        string     `json:"name"`
	ByteSize    int64      `json:"byteSize"`
	IsDirectory bool       `json:"isDirectory"`
	Children    []TreeNode `json:"children,omitempty"`
}

// Treemap lists immediate children of root with sizes (one level for UI drill-down).
func Treemap(root string, maxChildren int) TreeNode {
	if root == "" {
		root = fsutil.HomeDir()
	}
	root = filepath.Clean(root)
	info, err := os.Lstat(root)
	node := TreeNode{Path: root, Name: filepath.Base(root), IsDirectory: err == nil && info.IsDir()}
	if err != nil || safety.IsBlocked(root, safety.Opts{}) || whitelist.Excludes(root) {
		return node
	}
	if !info.IsDir() {
		node.ByteSize = info.Size()
		return node
	}
	entries, err := os.ReadDir(root)
	if err != nil {
		node.ByteSize = fsutil.DirectorySize(root, 12_000)
		return node
	}

	type childJob struct {
		full, name string
		isDir      bool
		fileSize   int64
	}
	var jobs []childJob
	for _, ent := range entries {
		name := ent.Name()
		if strings.HasPrefix(name, ".") && name != ".Trash" {
			continue
		}
		full := filepath.Join(root, name)
		if safety.IsBlocked(full, safety.Opts{}) || whitelist.Excludes(full) {
			continue
		}
		typ := ent.Type()
		if typ&os.ModeSymlink != 0 {
			continue
		}
		if ent.IsDir() {
			jobs = append(jobs, childJob{full: full, name: name, isDir: true})
			continue
		}
		if !typ.IsRegular() {
			continue
		}
		st, err := ent.Info()
		if err != nil {
			continue
		}
		jobs = append(jobs, childJob{full: full, name: name, fileSize: st.Size()})
	}

	kids := make([]TreeNode, len(jobs))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)
	for i, job := range jobs {
		wg.Add(1)
		go func(i int, job childJob) {
			defer wg.Done()
			child := TreeNode{Path: job.full, Name: job.name, IsDirectory: job.isDir}
			if job.isDir {
				sem <- struct{}{}
				// ponytail: 12k cap + parallel children — raise if treemap under-reports huge folders.
				child.ByteSize = fsutil.DirectorySize(job.full, 12_000)
				<-sem
			} else {
				child.ByteSize = job.fileSize
			}
			kids[i] = child
		}(i, job)
	}
	wg.Wait()

	var total int64
	compact := kids[:0]
	for _, c := range kids {
		if c.ByteSize <= 0 {
			continue
		}
		total += c.ByteSize
		compact = append(compact, c)
	}
	kids = compact
	sort.Slice(kids, func(i, j int) bool { return kids[i].ByteSize > kids[j].ByteSize })
	if maxChildren > 0 && len(kids) > maxChildren {
		kids = kids[:maxChildren]
	}
	node.Children = kids
	if total > 0 {
		node.ByteSize = total
	} else {
		node.ByteSize = fsutil.DirectorySize(root, 12_000)
	}
	return node
}
