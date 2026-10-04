package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"sync"

	"github.com/Hasninemamud/CleanMac/internal/apps"
	"github.com/Hasninemamud/CleanMac/internal/disk"
	"github.com/Hasninemamud/CleanMac/internal/doctor"
	"github.com/Hasninemamud/CleanMac/internal/duplicates"
	"github.com/Hasninemamud/CleanMac/internal/fsutil"
	"github.com/Hasninemamud/CleanMac/internal/installers"
	"github.com/Hasninemamud/CleanMac/internal/jsonout"
	"github.com/Hasninemamud/CleanMac/internal/junk"
	"github.com/Hasninemamud/CleanMac/internal/oplog"
	"github.com/Hasninemamud/CleanMac/internal/optimize"
	"github.com/Hasninemamud/CleanMac/internal/purge"
	"github.com/Hasninemamud/CleanMac/internal/software"
	"github.com/Hasninemamud/CleanMac/internal/status"
	"github.com/Hasninemamud/CleanMac/internal/whitelist"
)

const version = "2.2.5"

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
	case "clean":
		runClean(args)
	case "junk":
		runJunk(args)
	case "installer", "installers":
		runInstallers(args)
	case "purge":
		runPurge(args)
	case "apps", "uninstall":
		runApps(args)
	case "software":
		runSoftware(args)
	case "analyze":
		runAnalyze(args)
	case "optimize":
		runOptimize(args)
	case "status":
		runStatus(args)
	case "whitelist":
		runWhitelist(args)
	case "history":
		runHistory(args)
	case "doctor":
		outJSON(map[string]any{"checks": doctor.Run()})
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
  cleanmac clean --json
  cleanmac junk --json
  cleanmac installer --json
  cleanmac purge --json
  cleanmac apps --json
  cleanmac software updates|startup --json
  cleanmac software startup --enable|--disable <path> --json
  cleanmac analyze overview|large|dupes|treemap --json
  cleanmac optimize [--dry-run] [--id dns,finder] --json
  cleanmac status --json
  cleanmac whitelist list|add|remove --json
  cleanmac history --json
  cleanmac doctor --json
  cleanmac version
`, version)
}

func wantJSON(args []string) bool {
	for _, a := range args {
		if a == "--json" {
			return true
		}
	}
	return true
}

func progress() func(int, string) {
	return func(n int, p string) { jsonout.ProgressStderr(n, p) }
}

func runClean(args []string) {
	_ = args
	var junkItems, installerItems, purgeItems []jsonout.Item
	var wg sync.WaitGroup
	wg.Add(3)
	go func() {
		defer wg.Done()
		junkItems = junk.Scan(nil)
		if junkItems == nil {
			junkItems = []jsonout.Item{}
		}
	}()
	go func() {
		defer wg.Done()
		installerItems = installers.Scan()
		if installerItems == nil {
			installerItems = []jsonout.Item{}
		}
	}()
	go func() {
		defer wg.Done()
		purgeItems = purge.Scan(nil)
		if purgeItems == nil {
			purgeItems = []jsonout.Item{}
		}
	}()
	wg.Wait()
	outJSON(map[string]any{
		"junk":       junkItems,
		"installers": installerItems,
		"purge":      purgeItems,
	})
}

func runJunk(args []string) {
	_ = args
	items := junk.Scan(progress())
	if items == nil {
		items = []jsonout.Item{}
	}
	outJSON(map[string]any{"items": items})
}

func runInstallers(args []string) {
	_ = args
	items := installers.Scan()
	if items == nil {
		items = []jsonout.Item{}
	}
	outJSON(map[string]any{"items": items})
}

func runPurge(args []string) {
	_ = args
	items := purge.Scan(progress())
	if items == nil {
		items = []jsonout.Item{}
	}
	outJSON(map[string]any{"items": items})
}

func runApps(args []string) {
	_ = args
	outJSON(apps.Scan())
}

func runSoftware(args []string) {
	if len(args) < 1 {
		jsonout.Fail(fmt.Errorf("software requires updates|startup"))
	}
	sub := args[0]
	rest := args[1:]
	switch sub {
	case "updates":
		outJSON(map[string]any{"items": software.ListUpdates()})
	case "startup":
		fs := flag.NewFlagSet("startup", flag.ExitOnError)
		enable := fs.String("enable", "", "path to enable")
		disable := fs.String("disable", "", "path to disable")
		_ = fs.Parse(filterFlags(rest))
		if *enable != "" {
			if err := software.SetStartupEnabled(*enable, true); err != nil {
				jsonout.Fail(err)
			}
			oplog.Append("startup-enable", []string{*enable}, 0, "")
		}
		if *disable != "" {
			if err := software.SetStartupEnabled(*disable, false); err != nil {
				jsonout.Fail(err)
			}
			oplog.Append("startup-disable", []string{*disable}, 0, "")
		}
		outJSON(map[string]any{"items": software.ListStartup()})
	default:
		jsonout.Fail(fmt.Errorf("unknown software subcommand: %s", sub))
	}
}

func runAnalyze(args []string) {
	if len(args) < 1 {
		jsonout.Fail(fmt.Errorf("analyze requires overview|large|dupes|treemap"))
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
		files := disk.CollectLarge(fsutil.HomeDir(), 1_048_576, 5000, progress())
		groups := duplicates.Find(files, 1_048_576, progress())
		outJSON(map[string]any{"groups": groups})
	case "treemap":
		fs := flag.NewFlagSet("treemap", flag.ExitOnError)
		root := fs.String("path", fsutil.HomeDir(), "folder to map")
		_ = fs.Parse(filterFlags(rest))
		outJSON(disk.Treemap(*root, 80))
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
	res := optimize.Run(idList, *dry)
	if !*dry {
		var done []string
		for _, a := range res.Actions {
			if a.Status == "ok" {
				done = append(done, a.ID)
			}
		}
		oplog.Append("optimize", done, 0, strings.Join(done, ","))
	}
	outJSON(res)
}

func runStatus(args []string) {
	_ = args
	outJSON(status.Collect())
}

func runWhitelist(args []string) {
	if len(args) < 1 {
		jsonout.Fail(fmt.Errorf("whitelist requires list|add|remove"))
	}
	switch args[0] {
	case "list":
		paths := whitelist.Load()
		if paths == nil {
			paths = []string{}
		}
		outJSON(map[string]any{"paths": paths})
	case "add":
		if len(args) < 2 {
			jsonout.Fail(fmt.Errorf("whitelist add <path>"))
		}
		if err := whitelist.Add(args[1]); err != nil {
			jsonout.Fail(err)
		}
		outJSON(map[string]any{"paths": whitelist.Load()})
	case "remove":
		if len(args) < 2 {
			jsonout.Fail(fmt.Errorf("whitelist remove <path>"))
		}
		if err := whitelist.Remove(args[1]); err != nil {
			jsonout.Fail(err)
		}
		outJSON(map[string]any{"paths": whitelist.Load()})
	default:
		jsonout.Fail(fmt.Errorf("unknown whitelist subcommand"))
	}
}

func runHistory(args []string) {
	_ = args
	outJSON(map[string]any{"entries": oplog.Tail(100)})
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
