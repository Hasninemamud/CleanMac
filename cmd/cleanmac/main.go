package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/Hasninemamud/CleanMac/internal/apps"
	"github.com/Hasninemamud/CleanMac/internal/disk"
	"github.com/Hasninemamud/CleanMac/internal/duplicates"
	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/installers"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/junk"
	"github.com/Hasninemamud/CleanMac/internal/optimize"
	"github.com/Hasninemamud/CleanMac/internal/purge"
	"github.com/Hasninemamud/CleanMac/internal/status"
)

const version = "2.1.0"

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	cmd := os.Args[1]
	args := os.Args[2:]
	switch cmd {
	case "version", "--version", "-v":
		fmt.Println(version)
	case "junk":
		runJunk(args)
	case "installer", "installers":
		runInstallers(args)
	case "purge":
		runPurge(args)
	case "apps", "uninstall":
		runApps(args)
	case "analyze":
		runAnalyze(args)
	case "optimize":
		runOptimize(args)
	case "status":
		runStatus(args)
	case "help", "-h", "--help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", cmd)
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintf(os.Stderr, `cleanmac %s — Mac space cleaner kernel

Usage:
  cleanmac junk --json
  cleanmac installer --json
  cleanmac purge --json
  cleanmac apps --json
  cleanmac analyze overview|large|dupes --json
  cleanmac optimize [--dry-run] [--id dns,finder] --json
  cleanmac status --json
  cleanmac version
`, version)
}

func wantJSON(args []string) bool {
	for _, a := range args {
		if a == "--json" {
			return true
		}
	}
	return true // default JSON for UI bridge
}

func progress() func(int, string) {
	return func(n int, p string) { jsonout.ProgressStderr(n, p) }
}

func runJunk(args []string) {
	_ = args
	items := junk.Scan(progress())
	outJSON(map[string]any{"items": items})
}

func runInstallers(args []string) {
	_ = args
	outJSON(map[string]any{"items": installers.Scan()})
}

func runPurge(args []string) {
	_ = args
	outJSON(map[string]any{"items": purge.Scan(progress())})
}

func runApps(args []string) {
	_ = args
	outJSON(apps.Scan())
}

func runAnalyze(args []string) {
	if len(args) < 1 {
		jsonout.Fail(fmt.Errorf("analyze requires overview|large|dupes"))
	}
	sub := args[0]
	rest := args[1:]
	switch sub {
	case "overview":
		outJSON(disk.ScanOverview(progress()))
	case "large":
		fs := flag.NewFlagSet("large", flag.ExitOnError)
		minMB := fs.Int64("min-mb", 50, "minimum file size in MB")
		root := fs.String("root", fsutil.HomeDir(), "scan root")
		_ = fs.Parse(filterFlags(rest))
		items := disk.CollectLarge(*root, (*minMB)*1024*1024, 5000, progress())
		outJSON(map[string]any{"items": items})
	case "dupes":
		// Scan large files first (≥1MB), then hash
		files := disk.CollectLarge(fsutil.HomeDir(), 1_048_576, 5000, progress())
		groups := duplicates.Find(files, 1_048_576, progress())
		outJSON(map[string]any{"groups": groups})
	default:
		jsonout.Fail(fmt.Errorf("unknown analyze subcommand: %s", sub))
	}
}

func runOptimize(args []string) {
	fs := flag.NewFlagSet("optimize", flag.ExitOnError)
	dry := fs.Bool("dry-run", false, "preview only")
	ids := fs.String("id", "", "comma-separated action ids")
	_ = fs.Parse(filterFlags(args))
	var idList []string
	if *ids != "" {
		idList = strings.Split(*ids, ",")
	}
	outJSON(optimize.Run(idList, *dry))
}

func runStatus(args []string) {
	_ = args
	outJSON(status.Collect())
}

func filterFlags(args []string) []string {
	var out []string
	for _, a := range args {
		if a == "--json" {
			continue
		}
		out = append(out, a)
	}
	return out
}

func outJSON(v any) {
	_ = wantJSON(nil)
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		jsonout.Fail(err)
	}
}
