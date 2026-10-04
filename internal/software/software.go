package software

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
)

type UpdateItem struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Source  string `json:"source"` // homebrew-cask|homebrew-formula|mas|website
	Current string `json:"current,omitempty"`
	Latest  string `json:"latest,omitempty"`
	Detail  string `json:"detail,omitempty"`
	// Group: in-app (brew can upgrade) | outside (App Store / manual) | current (up to date — filled in Swift)
	Group string `json:"group,omitempty"`
}

type StartupItem struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Path    string `json:"path"`
	Kind    string `json:"kind"` // login-item|background-item|launch-agent|launch-daemon
	Enabled bool   `json:"enabled"`
	Detail  string `json:"detail,omitempty"`
}

func ListUpdates() []UpdateItem {
	var out []UpdateItem
	if bin, err := exec.LookPath("brew"); err == nil {
		out = append(out, brewOutdated(bin, true)...)
		out = append(out, brewOutdated(bin, false)...)
	}
	out = append(out, UpdateItem{
		ID: "mas-updates", Name: "Mac App Store updates",
		Source: "mas", Group: "outside",
		Detail: "Open App Store → Updates",
	})
	return out
}

type brewOutdatedJSON struct {
	Formulae []brewOutdatedEntry `json:"formulae"`
	Casks    []brewOutdatedEntry `json:"casks"`
}

type brewOutdatedEntry struct {
	Name              string   `json:"name"`
	InstalledVersions []string `json:"installed_versions"`
	CurrentVersion    string   `json:"current_version"`
}

func brewOutdated(bin string, cask bool) []UpdateItem {
	args := []string{"outdated", "--json=v2"}
	if cask {
		args = []string{"outdated", "--cask", "--json=v2"}
	} else {
		args = []string{"outdated", "--formula", "--json=v2"}
	}
	b, err := exec.Command(bin, args...).Output()
	if err != nil || len(b) == 0 {
		return brewOutdatedQuiet(bin, cask)
	}
	var parsed brewOutdatedJSON
	if err := json.Unmarshal(b, &parsed); err != nil {
		return brewOutdatedQuiet(bin, cask)
	}
	entries := parsed.Formulae
	source := "homebrew-formula"
	if cask {
		entries = parsed.Casks
		source = "homebrew-cask"
	}
	// Some brew versions put both in one blob regardless of flag.
	if cask && len(entries) == 0 && len(parsed.Casks) > 0 {
		entries = parsed.Casks
	}
	if !cask && len(entries) == 0 && len(parsed.Formulae) > 0 {
		entries = parsed.Formulae
	}
	var out []UpdateItem
	for _, e := range entries {
		cur := ""
		if len(e.InstalledVersions) > 0 {
			cur = e.InstalledVersions[0]
		}
		out = append(out, UpdateItem{
			ID: source + ":" + e.Name, Name: e.Name, Source: source,
			Current: cur, Latest: e.CurrentVersion, Group: "in-app",
			Detail: "brew upgrade " + e.Name,
		})
	}
	return out
}

func brewOutdatedQuiet(bin string, cask bool) []UpdateItem {
	args := []string{"outdated", "--formula", "--quiet"}
	source := "homebrew-formula"
	if cask {
		args = []string{"outdated", "--cask", "--quiet"}
		source = "homebrew-cask"
	}
	b, err := exec.Command(bin, args...).Output()
	if err != nil {
		return nil
	}
	var out []UpdateItem
	for _, line := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		out = append(out, UpdateItem{
			ID: source + ":" + line, Name: line, Source: source, Group: "in-app",
			Detail: "brew upgrade " + line,
		})
	}
	return out
}

func ListStartup() []StartupItem {
	home := fsutil.HomeDir()
	var out []StartupItem

	// Login Items via System Events (best-effort).
	if b, err := exec.Command("osascript", "-e",
		`tell application "System Events" to get name of every login item`).Output(); err == nil {
		raw := strings.TrimSpace(string(b))
		if raw != "" && !strings.HasPrefix(strings.ToLower(raw), "error") {
			for _, name := range strings.Split(raw, ", ") {
				name = strings.TrimSpace(name)
				if name == "" {
					continue
				}
				out = append(out, StartupItem{
					ID: "login:" + name, Name: name, Path: name,
					Kind: "login-item", Enabled: true, Detail: "App",
				})
			}
		}
	}

	agents := filepath.Join(home, "Library/LaunchAgents")
	if ents, err := os.ReadDir(agents); err == nil {
		for _, e := range ents {
			if e.IsDir() || !strings.HasSuffix(e.Name(), ".plist") {
				continue
			}
			full := filepath.Join(agents, e.Name())
			name := strings.TrimSuffix(e.Name(), ".plist")
			kind := "launch-agent"
			detail := "Launch Agent"
			low := strings.ToLower(name)
			if strings.Contains(low, "updater") || strings.Contains(low, "helper") ||
				strings.Contains(low, "agent") || strings.Contains(low, "background") {
				kind = "background-item"
				detail = "App"
			}
			out = append(out, StartupItem{
				ID: full, Name: name, Path: full, Kind: kind, Enabled: true, Detail: detail,
			})
		}
	}
	disabled := filepath.Join(home, "Library/LaunchAgentsDisabled")
	if ents, err := os.ReadDir(disabled); err == nil {
		for _, e := range ents {
			if e.IsDir() || !strings.HasSuffix(e.Name(), ".plist") {
				continue
			}
			full := filepath.Join(disabled, e.Name())
			name := strings.TrimSuffix(e.Name(), ".plist")
			out = append(out, StartupItem{
				ID: full, Name: name, Path: full, Kind: "launch-agent", Enabled: false,
				Detail: "Disabled Launch Agent",
			})
		}
	}
	return out
}

// SetStartupEnabled moves a user LaunchAgent between LaunchAgents and LaunchAgentsDisabled.
// Login items cannot be toggled here (System Settings).
func SetStartupEnabled(path string, enabled bool) error {
	if strings.HasPrefix(path, "login:") {
		return nil
	}
	home := fsutil.HomeDir()
	agents := filepath.Join(home, "Library/LaunchAgents")
	disabled := filepath.Join(home, "Library/LaunchAgentsDisabled")
	base := filepath.Base(path)
	if enabled {
		_ = os.MkdirAll(agents, 0o755)
		dest := filepath.Join(agents, base)
		if err := os.Rename(path, dest); err != nil {
			return err
		}
		_ = exec.Command("launchctl", "load", dest).Run()
		return nil
	}
	_ = os.MkdirAll(disabled, 0o755)
	_ = exec.Command("launchctl", "unload", path).Run()
	return os.Rename(path, filepath.Join(disabled, base))
}
