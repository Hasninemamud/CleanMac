package disk

import (
	"os"
	"path/filepath"
	"sort"
	"strings"

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
		node.ByteSize = fsutil.DirectorySize(root, 80_000)
		return node
	}
	var kids []TreeNode
	var total int64
	for _, ent := range entries {
		name := ent.Name()
		if strings.HasPrefix(name, ".") && name != ".Trash" {
			continue
		}
		full := filepath.Join(root, name)
		if safety.IsBlocked(full, safety.Opts{}) || whitelist.Excludes(full) {
			continue
		}
		st, err := ent.Info()
		if err != nil || st.Mode()&os.ModeSymlink != 0 {
			continue
		}
		child := TreeNode{Path: full, Name: name, IsDirectory: ent.IsDir()}
		if ent.IsDir() {
			child.ByteSize = fsutil.DirectorySize(full, 60_000)
		} else if st.Mode().IsRegular() {
			child.ByteSize = st.Size()
		} else {
			continue
		}
		if child.ByteSize <= 0 {
			continue
		}
		total += child.ByteSize
		kids = append(kids, child)
	}
	sort.Slice(kids, func(i, j int) bool { return kids[i].ByteSize > kids[j].ByteSize })
	if maxChildren > 0 && len(kids) > maxChildren {
		kids = kids[:maxChildren]
	}
	node.Children = kids
	if total > 0 {
		node.ByteSize = total
	} else {
		node.ByteSize = fsutil.DirectorySize(root, 40_000)
	}
	return node
}
