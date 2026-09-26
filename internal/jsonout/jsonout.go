package jsonout

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
)

// Item is the shared scan result shape for the Swift UI.
type Item struct {
	Path        string  `json:"path"`
	Name        string  `json:"name"`
	ByteSize    int64   `json:"byteSize"`
	Safety      string  `json:"safety"`
	Category    string  `json:"category,omitempty"`
	Explanation string  `json:"explanation,omitempty"`
	ModifiedAt  float64 `json:"modifiedAt,omitempty"`
	IsDirectory bool    `json:"isDirectory,omitempty"`
	Source      string  `json:"source,omitempty"`
	Project     string  `json:"project,omitempty"`
	ProjectPath string  `json:"projectPath,omitempty"`
	AgeDays     float64 `json:"ageDays,omitempty"`
	Kind        string  `json:"kind,omitempty"`
	Orphan      bool    `json:"orphan,omitempty"`
	Root        string  `json:"root,omitempty"`
}

type Progress struct {
	Type         string `json:"type"`
	PathsVisited int    `json:"pathsVisited"`
	CurrentPath  string `json:"currentPath,omitempty"`
}

func WriteJSON(w io.Writer, v any) error {
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	return enc.Encode(v)
}

func ProgressTo(w io.Writer, visited int, current string) {
	_ = WriteJSON(w, Progress{Type: "progress", PathsVisited: visited, CurrentPath: current})
}

func ProgressStderr(visited int, current string) {
	ProgressTo(os.Stderr, visited, current)
}

func Fail(err error) {
	fmt.Fprintln(os.Stderr, err.Error())
	os.Exit(1)
}
