package optimize

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
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
			ID: "ql", Title: "Reset Quick Look cache",
			Explanation: "Clears Quick Look thumbnails (user cache).",
			NeedsSudo: false, DryRunOK: true,
			Command: []string{"qlmanage", "-r", "cache"},
		},
		{
			ID: "fontcache", Title: "Clear user font caches",
			Explanation: "Removes ATS font cache folders under Library/Caches.",
			NeedsSudo: false, DryRunOK: true,
			Command: []string{"/bin/rm", "-rf", "$HOME/Library/Caches/com.apple.ATS"},
		},
		{
			ID: "iconcache", Title: "Refresh icon services",
			Explanation: "Restarts iconservices agents to clear stale icons.",
			NeedsSudo: false, DryRunOK: true,
			Command: []string{"killall", "-KILL", "iconservicesagent"},
		},
		{
			ID: "sqlite", Title: "Vacuum known SQLite caches",
			Explanation: "VACUUM small Safari/Mail/Messages cache DBs when those apps are not running.",
			NeedsSudo: false, DryRunOK: true,
		},
		{
			ID: "notifications", Title: "Clear notification history",
			Explanation: "Removes delivered notifications from Notification Center DB when found.",
			NeedsSudo: false, DryRunOK: true,
		},
		{
			ID: "savedstate", Title: "Clear dead app saved state",
			Explanation: "Removes Saved Application State folders older than 30 days for apps that are gone.",
			NeedsSudo: false, DryRunOK: true,
		},
		{
			ID: "quarantine", Title: "Clear Gatekeeper quarantine attrs (Downloads)",
			Explanation: "Removes com.apple.quarantine from files in Downloads. Review first.",
			NeedsSudo: false, DryRunOK: true,
			Command: []string{"xattr", "-cr", "$HOME/Downloads"},
		},
		{
			ID: "quarantinedb", Title: "Clear quarantine event history",
			Explanation: "Deletes rows from LaunchServices QuarantineEventsV2 (download tracking only).",
			NeedsSudo: false, DryRunOK: true,
		},
		{
			ID: "loginitems", Title: "Audit login items",
			Explanation: "Reports login items / LaunchAgents whose program is missing (no deletes).",
			NeedsSudo: false, DryRunOK: true,
		},
		{
			ID: "spotlight", Title: "Rebuild Spotlight index (home)",
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
			ID: "dock", Title: "Relaunch Dock",
			Explanation: "Restarts Dock to refresh icons and layout.",
			NeedsSudo: false, DryRunOK: true,
			Command: []string{"killall", "Dock"},
		},
		{
			ID: "dns", Title: "Flush DNS cache",
			Explanation: "Clears the system DNS resolver cache.",
			NeedsSudo: true, DryRunOK: true,
			Command: []string{"dscacheutil", "-flushcache"},
		},
		{
			ID: "periodic", Title: "Run periodic maintenance",
			Explanation: "Runs macOS daily/weekly/monthly scripts when available.",
			NeedsSudo: true, DryRunOK: true,
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
			a.Detail = "dry-run — would run when confirmed"
			out = append(out, a)
			continue
		}
		if a.NeedsSudo {
			a.Status = "skipped"
			a.Detail = "requires admin — run from Terminal with sudo if needed"
			out = append(out, a)
			continue
		}
		var err error
		var detail string
		switch a.ID {
		case "sqlite":
			detail, err = vacuumKnownSQLite()
		case "notifications":
			detail, err = clearNotifications()
		case "savedstate":
			detail, err = clearOldSavedState()
		case "quarantinedb":
			detail, err = clearQuarantineDB()
		case "loginitems":
			detail, err = auditLoginItems()
		case "periodic":
			a.Status = "skipped"
			a.Detail = "requires admin — periodic scripts need sudo"
			out = append(out, a)
			continue
		default:
			args := expandHome(a.Command)
			if len(args) == 0 {
				a.Status = "skipped"
				a.Detail = "no command"
				out = append(out, a)
				continue
			}
			err = exec.Command(args[0], args[1:]...).Run()
			if err == nil {
				detail = "completed"
			}
		}
		if err != nil {
			a.Status = "error"
			a.Detail = err.Error()
		} else {
			a.Status = "ok"
			a.Detail = detail
			if a.Detail == "" {
				a.Detail = "completed"
			}
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

func processRunning(names ...string) bool {
	out, err := exec.Command("pgrep", "-x", names[0]).Output()
	if err == nil && len(strings.TrimSpace(string(out))) > 0 {
		return true
	}
	for _, n := range names[1:] {
		out, err := exec.Command("pgrep", "-x", n).Output()
		if err == nil && len(strings.TrimSpace(string(out))) > 0 {
			return true
		}
	}
	return false
}

func vacuumKnownSQLite() (string, error) {
	home := os.Getenv("HOME")
	const maxBytes = 100 << 20 // 100MB
	var vacuumed, skipped int

	tryVacuum := func(path string, blockers []string) {
		info, err := os.Stat(path)
		if err != nil || info.IsDir() || info.Size() == 0 || info.Size() > maxBytes {
			return
		}
		low := strings.ToLower(path)
		if !strings.HasSuffix(low, ".db") && !strings.HasSuffix(low, ".sqlite") && !strings.HasSuffix(low, ".sqlite3") {
			return
		}
		for _, b := range blockers {
			if processRunning(b) {
				skipped++
				return
			}
		}
		if err := exec.Command("sqlite3", path, "VACUUM;").Run(); err != nil {
			skipped++
			return
		}
		vacuumed++
	}

	// Known regenerable DBs — do not walk huge trees.
	known := []struct {
		path     string
		blockers []string
	}{
		{filepath.Join(home, "Library/Safari/PerSitePreferences.db"), []string{"Safari"}},
		{filepath.Join(home, "Library/Caches/com.apple.Safari/Cache.db"), []string{"Safari"}},
		{filepath.Join(home, "Library/Caches/CloudKit/CloudKitMetadata.db"), nil},
	}
	for _, d := range known {
		tryVacuum(d.path, d.blockers)
	}
	if vacuumed == 0 && skipped == 0 {
		return "no eligible SQLite caches found", nil
	}
	return itoa(vacuumed) + " vacuumed, " + itoa(skipped) + " skipped", nil
}

func clearNotifications() (string, error) {
	home := os.Getenv("HOME")
	base := filepath.Join(home, "Library/Group Containers/group.com.apple.usernoted/Library/Application Support")
	// Darwin user dirs vary; probe common Notification Center db2 locations.
	candidates := []string{
		filepath.Join(home, "Library/Application Support/NotificationCenter"),
	}
	entries, _ := os.ReadDir(filepath.Join(home, "Library/Group Containers"))
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		name := e.Name()
		if !strings.Contains(strings.ToLower(name), "note") && !strings.Contains(name, "usernoted") {
			continue
		}
		candidates = append(candidates,
			filepath.Join(home, "Library/Group Containers", name, "Library/Application Support"),
		)
	}
	_ = base
	var dbPath string
	for _, c := range candidates {
		_ = filepath.Walk(c, func(path string, info os.FileInfo, err error) error {
			if err != nil || info == nil || info.IsDir() {
				return nil
			}
			if filepath.Base(path) == "db" && strings.Contains(path, "notificationcenter") {
				dbPath = path
				return filepath.SkipAll
			}
			if filepath.Base(path) == "db" && strings.Contains(strings.ToLower(path), "notification") {
				dbPath = path
				return filepath.SkipAll
			}
			return nil
		})
		if dbPath != "" {
			break
		}
	}
	if dbPath == "" {
		return "Notification Center database unavailable", nil
	}
	// Delete delivered records when schema supports it; ignore SQL errors for schema drift.
	_ = exec.Command("sqlite3", dbPath, "DELETE FROM recorded;").Run()
	_ = exec.Command("sqlite3", dbPath, "DELETE FROM delivered;").Run()
	_ = exec.Command("sqlite3", dbPath, "VACUUM;").Run()
	return "notification history cleared", nil
}

func clearOldSavedState() (string, error) {
	home := os.Getenv("HOME")
	dir := filepath.Join(home, "Library/Saved Application State")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "no saved application state", nil
	}
	cutoff := time.Now().Add(-30 * 24 * time.Hour)
	removed := 0
	for _, e := range entries {
		if !e.IsDir() || !strings.HasSuffix(e.Name(), ".savedState") {
			continue
		}
		full := filepath.Join(dir, e.Name())
		info, err := e.Info()
		if err != nil || info.ModTime().After(cutoff) {
			continue
		}
		// Bundle id before .savedState — skip if matching .app still installed in /Applications.
		bid := strings.TrimSuffix(e.Name(), ".savedState")
		if appStillInstalled(bid) {
			continue
		}
		if err := os.RemoveAll(full); err == nil {
			removed++
		}
	}
	return itoa(removed) + " old saved states removed", nil
}

func appStillInstalled(bundleID string) bool {
	// Cheap heuristic: mdfind or Applications scan by bundle id folder name fragments.
	out, err := exec.Command("mdfind", "kMDItemCFBundleIdentifier == '"+bundleID+"'").Output()
	if err == nil && len(strings.TrimSpace(string(out))) > 0 {
		return true
	}
	return false
}

func clearQuarantineDB() (string, error) {
	home := os.Getenv("HOME")
	db := filepath.Join(home, "Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2")
	if _, err := os.Stat(db); err != nil {
		return "quarantine database already clean", nil
	}
	if err := exec.Command("sqlite3", db, "DELETE FROM LSQuarantineEvent; VACUUM;").Run(); err != nil {
		return "", err
	}
	return "quarantine history cleared", nil
}

func auditLoginItems() (string, error) {
	home := os.Getenv("HOME")
	dirs := []string{
		filepath.Join(home, "Library/LaunchAgents"),
	}
	missing := 0
	checked := 0
	for _, dir := range dirs {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() || !strings.HasSuffix(e.Name(), ".plist") {
				continue
			}
			checked++
			full := filepath.Join(dir, e.Name())
			out, err := exec.Command("plutil", "-extract", "ProgramArguments.0", "raw", "-o", "-", full).Output()
			prog := strings.TrimSpace(string(out))
			if err != nil || prog == "" {
				out2, err2 := exec.Command("plutil", "-extract", "Program", "raw", "-o", "-", full).Output()
				if err2 != nil {
					continue
				}
				prog = strings.TrimSpace(string(out2))
			}
			if prog == "" {
				continue
			}
			if _, err := os.Stat(prog); err != nil {
				missing++
			}
		}
	}
	return itoa(checked) + " agents checked, " + itoa(missing) + " missing binaries", nil
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [12]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}
