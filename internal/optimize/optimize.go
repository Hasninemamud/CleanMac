package optimize

import (
	"os"
	"os/exec"
	"strings"
)

// Action is a user-confirm maintenance step. Run only when dryRun is false.
type Action struct {
	ID          string   `json:"id"`
	Title       string   `json:"title"`
	Explanation string   `json:"explanation"`
	NeedsSudo   bool     `json:"needsSudo"`
	DryRunOK    bool     `json:"dryRunOk"`
	Status      string   `json:"status"` // pending|ok|skipped|error
	Detail      string   `json:"detail,omitempty"`
	Command     []string `json:"-"`
}

func Catalog() []Action {
	return []Action{
		{
			ID: "dns", Title: "Flush DNS cache",
			Explanation: "Clears the system DNS resolver cache.",
			NeedsSudo: true, DryRunOK: true,
			Command: []string{"dscacheutil", "-flushcache"},
		},
		{
			ID: "mdutil", Title: "Rebuild Spotlight index (home)",
			Explanation: "Reindexes Spotlight for your home folder. May take a while.",
			NeedsSudo: false, DryRunOK: true,
			Command: []string{"mdutil", "-E", "$HOME"},
		},
		{
			ID: "finder", Title: "Relaunch Finder",
			Explanation: "Quits and reopens Finder to clear UI glitches.",
			NeedsSudo: false, DryRunOK: true,
			Command: []string{"killall", "Finder"},
		},
		{
			ID: "quarantine", Title: "Clear Gatekeeper quarantine attrs (Downloads)",
			Explanation: "Removes com.apple.quarantine from files in Downloads. Review first.",
			NeedsSudo: false, DryRunOK: true,
			Command: []string{"xattr", "-cr", "$HOME/Downloads"},
		},
	}
}

type Result struct {
	Actions []Action `json:"actions"`
	DryRun  bool     `json:"dryRun"`
}

func Run(ids []string, dryRun bool) Result {
	want := map[string]bool{}
	for _, id := range ids {
		want[id] = true
	}
	all := Catalog()
	var out []Action
	for _, a := range all {
		if len(want) > 0 && !want[a.ID] {
			continue
		}
		a.Status = "pending"
		if dryRun {
			a.Status = "ok"
			a.Detail = "dry-run"
			out = append(out, a)
			continue
		}
		if a.NeedsSudo {
			a.Status = "skipped"
			a.Detail = "requires admin — run from Terminal with sudo if needed"
			out = append(out, a)
			continue
		}
		args := expandHome(a.Command)
		cmd := exec.Command(args[0], args[1:]...)
		if err := cmd.Run(); err != nil {
			a.Status = "error"
			a.Detail = err.Error()
		} else {
			a.Status = "ok"
		}
		out = append(out, a)
	}
	return Result{Actions: out, DryRun: dryRun}
}

func expandHome(args []string) []string {
	h := os.Getenv("HOME")
	out := make([]string, len(args))
	for i, a := range args {
		out[i] = strings.ReplaceAll(a, "$HOME", h)
	}
	return out
}
