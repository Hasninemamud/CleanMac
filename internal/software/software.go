package software

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/Hasninemamud/CleanMac/internal/fsutil"
)

type UpdateItem struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Source  string `json:"source"` // homebrew-cask|homebrew-formula|mas
	Current string `json:"current,omitempty"`
	Latest  string `json:"latest,omitempty"`
	Detail  string `json:"detail,omitempty"`
}

type StartupItem struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Path    string `json:"path"`
	Kind    string `json:"kind"` // launch-agent|login-item
	Enabled bool   `json:"enabled"`
	Detail  string `json:"detail,omitempty"`
}

func ListUpdates() []UpdateItem {
	var out []UpdateItem
	if bin, err := exec.LookPath("brew"); err == nil {
		cmd := exec.Command(bin, "outdated", "--cask", "--json=v2")
		if b, err := cmd.Output(); err == nil {
			out = append(out, parseBrewOutdated(string(b), "homebrew-cask")...)
		}
		cmd = exec.Command(bin, "outdated", "--formula", "--json=v2")
		if b, err := cmd.Output(); err == nil {
			out = append(out, parseBrewOutdated(string(b), "homebrew-formula")...)
		}
	}
	// Mac App Store hint — open App Store updates page (no silent update).
	out = append(out, UpdateItem{
		ID: "mas-updates", Name: "Mac App Store updates",
		Source: "mas", Detail: "Open App Store → Updates to review system apps",
	})
	return out
}

func parseBrewOutdated(jsonText, source string) []UpdateItem {
	// Lightweight parse without importing encoding/json quirks for nested brew shape:
	// look for "name" fields in a simple way via brew formula/cask list text fallback.
	_ = jsonText
	bin, err := exec.LookPath("brew")
	if err != nil {
		return nil
	}
	args := []string{"outdated", "--quiet"}
	if source == "homebrew-cask" {
		args = []string{"outdated", "--cask", "--quiet"}
	} else {
		args = []string{"outdated", "--formula", "--quiet"}
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
			ID: source + ":" + line, Name: line, Source: source,
			Detail: "brew upgrade " + line,
		})
	}
	return out
}

func ListStartup() []StartupItem {
	home := fsutil.HomeDir()
	var out []StartupItem
	agents := filepath.Join(home, "Library/LaunchAgents")
	if ents, err := os.ReadDir(agents); err == nil {
		for _, e := range ents {
			if e.IsDir() || !strings.HasSuffix(e.Name(), ".plist") {
				continue
			}
			full := filepath.Join(agents, e.Name())
			name := strings.TrimSuffix(e.Name(), ".plist")
			out = append(out, StartupItem{
				ID: full, Name: name, Path: full, Kind: "launch-agent", Enabled: true,
				Detail: "User LaunchAgent — disable moves plist aside",
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
				Detail: "Disabled LaunchAgent",
			})
		}
	}
	return out
}

// SetStartupEnabled moves a user LaunchAgent between LaunchAgents and LaunchAgentsDisabled.
func SetStartupEnabled(path string, enabled bool) error {
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
