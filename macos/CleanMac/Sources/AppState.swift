import Foundation
import AppKit
import Darwin
import IOKit.pwr_mgt

@Observable
@MainActor
final class AppState {
    var section: NavSection = .clean
    var cleanSegment: CleanSegment = .junk
    var analyzeSegment: AnalyzeSegment = .overview
    var softwareSegment: SoftwareSegment = .caches
    var statusLine = "Ready"
    var busy = false
    var errorMessage: String?
    var selected = Set<String>()
    var confirmTrash = false
    var showSettings = false
    var keepAwake = false
    var showCleanScreen = false
    private var assertID: IOPMAssertionID = 0

    var junk: [ScanItem] = []
    var installers: [ScanItem] = []
    var purgeItems: [ScanItem] = []
    var apps: [ScanItem] = []
    var orphans: [ScanItem] = []
    var overview: OverviewResponse?
    var large: [ScanItem] = []
    var dupes: [DupeGroup] = []
    var treemap: TreeNode?
    var treemapPath: String = NSHomeDirectory()
    var optimizeActions: [OptimizeAction] = []
    var metrics: StatusSnapshot?
    var updates: [UpdateItem] = []
    var startupItems: [StartupItem] = []
    var whitelist: [String] = []
    var doctorChecks: [DoctorCheck] = []
    var history: [HistoryEntry] = []

    enum NavSection: String, CaseIterable, Identifiable {
        case clean = "Clean"
        case software = "Software"
        case analyze = "Analyze"
        case optimize = "Optimize"
        case status = "Status"
        var id: String { rawValue }
    }

    enum CleanSegment: String, CaseIterable, Identifiable {
        case junk = "Junk"
        case installers = "Installers"
        case purge = "Purge"
        var id: String { rawValue }
    }

    enum AnalyzeSegment: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case map = "Map"
        case large = "Large"
        case dupes = "Dupes"
        var id: String { rawValue }
    }

    enum SoftwareSegment: String, CaseIterable, Identifiable {
        case caches = "Caches"
        case leftovers = "Leftovers"
        case orphans = "Orphans"
        case uninstall = "Uninstall"
        case updates = "Updates"
        case startup = "Startup"
        var id: String { rawValue }
    }

    var appLeftoverItems: [ScanItem] {
        apps.flatMap { $0.leftovers ?? [] }
    }

    var appCacheItems: [ScanItem] {
        let linked = appLeftoverItems.filter(\.isCacheLeftover)
        let orphanCaches = orphans.filter(\.isCacheLeftover)
        return (linked + orphanCaches).sorted { $0.byteSize > $1.byteSize }
    }

    var currentItems: [ScanItem] {
        switch section {
        case .clean:
            switch cleanSegment {
            case .junk: return junk
            case .installers: return installers
            case .purge: return purgeItems
            }
        case .software:
            switch softwareSegment {
            case .caches: return appCacheItems
            case .leftovers: return appLeftoverItems.sorted { $0.byteSize > $1.byteSize }
            case .orphans: return orphans
            case .uninstall: return apps.sorted { ($0.leftoverBytes ?? 0) > ($1.leftoverBytes ?? 0) }
            case .updates, .startup: return []
            }
        case .analyze:
            switch analyzeSegment {
            case .overview, .map: return []
            case .large: return large
            case .dupes: return dupes.flatMap(\.files)
            }
        default:
            return []
        }
    }

    var selectedBytes: Int64 {
        currentItems.filter { selected.contains($0.path) }.reduce(0) { $0 + $1.byteSize }
    }

    func scan(quiet: Bool = false) async {
        if !quiet {
            busy = true
            errorMessage = nil
            statusLine = "Scanning…"
        }
        defer { if !quiet { busy = false } }
        do {
            switch section {
            case .clean:
                switch cleanSegment {
                case .junk:
                    junk = try await CLIExecutor.shared.run(["junk", "--json"], as: ItemsResponse.self).items
                case .installers:
                    installers = try await CLIExecutor.shared.run(["installer", "--json"], as: ItemsResponse.self).items
                case .purge:
                    purgeItems = try await CLIExecutor.shared.run(["purge", "--json"], as: ItemsResponse.self).items
                }
            case .software:
                switch softwareSegment {
                case .caches, .leftovers, .orphans, .uninstall:
                    let r = try await CLIExecutor.shared.run(["apps", "--json"], as: AppsResponse.self)
                    apps = r.apps
                    orphans = r.orphans
                case .updates:
                    updates = try await CLIExecutor.shared.run(["software", "updates", "--json"], as: UpdatesResponse.self).items
                case .startup:
                    startupItems = try await CLIExecutor.shared.run(["software", "startup", "--json"], as: StartupResponse.self).items
                }
            case .analyze:
                switch analyzeSegment {
                case .overview:
                    overview = try await CLIExecutor.shared.run(["analyze", "overview", "--json"], as: OverviewResponse.self)
                case .map:
                    treemap = try await CLIExecutor.shared.run(
                        ["analyze", "treemap", "--path", treemapPath, "--json"],
                        as: TreeNode.self
                    )
                case .large:
                    large = try await CLIExecutor.shared.run(["analyze", "large", "--json"], as: ItemsResponse.self).items
                case .dupes:
                    let r = try await CLIExecutor.shared.run(["analyze", "dupes", "--json"], as: DupesResponse.self)
                    dupes = r.groups
                    selected = Set(r.groups.flatMap { Array($0.files.dropFirst()).map(\.path) })
                }
            case .optimize:
                optimizeActions = try await CLIExecutor.shared.run(["optimize", "--dry-run", "--json"], as: OptimizeResponse.self).actions
            case .status:
                metrics = try await CLIExecutor.shared.run(["status", "--json"], as: StatusSnapshot.self)
            }
            if !quiet {
                statusLine = "Done"
                if section != .analyze || analyzeSegment != .dupes {
                    selected.removeAll()
                }
            }
        } catch {
            if let cli = error as? CLIError, case .cancelled = cli {
                if !quiet { statusLine = "Stopped" }
            } else if !quiet {
                errorMessage = error.localizedDescription
                statusLine = "Error"
            }
        }
    }

    func stop() {
        guard busy else { return }
        CLIExecutor.shared.cancel()
        statusLine = "Stopping…"
    }

    func runOptimize(ids: [String], dryRun: Bool) async {
        busy = true
        defer { busy = false }
        do {
            var args = ["optimize", "--json"]
            if dryRun { args.insert("--dry-run", at: 1) }
            if !ids.isEmpty { args.append(contentsOf: ["--id", ids.joined(separator: ",")]) }
            let r = try await CLIExecutor.shared.run(args, as: OptimizeResponse.self)
            optimizeActions = r.actions
            statusLine = dryRun ? "Preview ready" : "Optimize finished"
        } catch {
            if let cli = error as? CLIError, case .cancelled = cli {
                statusLine = "Stopped"
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func trashSelected() async {
        let allowApps = section == .software && softwareSegment == .uninstall
        let paths = selected.filter {
            Safety.canTrash(path: $0, safety: "review", allowApps: allowApps)
                || Safety.canTrash(path: $0, safety: "safe", allowApps: allowApps)
        }
        .filter { !Safety.isBlocked($0, allowApps: allowApps) }
        let collapsed = collapseNested(Array(paths))
        var ok = 0
        var fail = 0
        var bytes: Int64 = 0
        for p in collapsed {
            do {
                var resulting: NSURL?
                let size = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                try FileManager.default.trashItem(at: URL(fileURLWithPath: p), resultingItemURL: &resulting)
                ok += 1
                bytes += size
                selected.remove(p)
            } catch {
                fail += 1
            }
        }
        statusLine = "Trashed \(ok)" + (fail > 0 ? ", \(fail) failed" : "")
        confirmTrash = false
        appendOpLog(action: "trash", paths: collapsed, bytes: bytes)
        await scan()
    }

    private func appendOpLog(action: String, paths: [String], bytes: Int64) {
        let dir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Logs/CleanMac")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = (dir as NSString).appendingPathComponent("operations.log")
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "time": formatter.string(from: Date()),
            "action": action,
            "paths": paths,
            "bytes": bytes,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            try? handle.close()
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func selectSafe() {
        selected = Set(currentItems.filter { $0.safety == "safe" }.map(\.path))
    }

    func loadSettingsData() async {
        do {
            whitelist = try await CLIExecutor.shared.run(["whitelist", "list", "--json"], as: WhitelistResponse.self).paths
            doctorChecks = try await CLIExecutor.shared.run(["doctor", "--json"], as: DoctorResponse.self).checks
            history = try await CLIExecutor.shared.run(["history", "--json"], as: HistoryResponse.self).entries
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addWhitelist(_ path: String) async {
        _ = try? await CLIExecutor.shared.run(["whitelist", "add", path, "--json"], as: WhitelistResponse.self)
        await loadSettingsData()
    }

    func removeWhitelist(_ path: String) async {
        _ = try? await CLIExecutor.shared.run(["whitelist", "remove", path, "--json"], as: WhitelistResponse.self)
        await loadSettingsData()
    }

    func setStartup(path: String, enabled: Bool) async {
        var args = ["software", "startup", "--json"]
        if enabled { args.insert(contentsOf: ["--enable", path], at: 2) }
        else { args.insert(contentsOf: ["--disable", path], at: 2) }
        do {
            startupItems = try await CLIExecutor.shared.run(args, as: StartupResponse.self).items
            statusLine = enabled ? "Startup enabled" : "Startup disabled"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openUpdate(_ item: UpdateItem) {
        if item.source == "mas" {
            NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
        } else if item.source.contains("homebrew") {
            // Reveal Terminal hint via open brew docs; copy upgrade cmd is enough in UI.
            NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
        }
    }

    func quitProcess(pid: Int) {
        kill(pid_t(pid), SIGTERM)
        statusLine = "Sent quit to PID \(pid)"
    }

    func toggleKeepAwake() {
        if keepAwake {
            IOPMAssertionRelease(assertID)
            keepAwake = false
            statusLine = "Allow sleep"
            return
        }
        var id: IOPMAssertionID = 0
        let name = "CleanMac Keep Screen On" as CFString
        let ok = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &id
        )
        if ok == kIOReturnSuccess {
            assertID = id
            keepAwake = true
            statusLine = "Keeping display awake"
        } else {
            errorMessage = "Could not create power assertion"
        }
    }

    private func collapseNested(_ paths: [String]) -> [String] {
        let sorted = paths.map(Safety.standardize).sorted { $0.count < $1.count }
        var kept: [String] = []
        for p in sorted {
            let covered = kept.contains { parent in
                p == parent || p.hasPrefix(parent.hasSuffix("/") ? parent : parent + "/")
            }
            if !covered { kept.append(p) }
        }
        return kept
    }
}
