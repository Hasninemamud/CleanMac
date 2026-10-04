import Foundation
import AppKit
import Darwin
import IOKit.pwr_mgt

@Observable
@MainActor
final class AppState {
    var section: NavSection = .clean
    var cleanSegment: CleanSegment = .junk
    var cleanPhase: CleanPhase = .hero
    var analyzeSegment: AnalyzeSegment = .map
    var analyzeSelectedPath: String?
    var softwareSegment: SoftwareSegment = .uninstall
    var appsSort: AppsSort = .lastUsed
    var appsQuery = ""
    var alsoRemoveData = true
    var ignoredUpdateIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "ignoredUpdateIDs") ?? [])
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
        case software = "Apps"
        case analyze = "Analyze"
        case optimize = "Optimize"
        case status = "Status"
        var id: String { rawValue }
    }

    enum CleanPhase: String {
        case hero
        case review
    }

    enum CleanSegment: String, CaseIterable, Identifiable {
        case junk = "Junk"
        case installers = "Installers"
        case purge = "Purge"
        var id: String { rawValue }
    }

    /// All Clean-tab scan results (junk + installers + purge).
    var cleanItems: [ScanItem] {
        junk + installers + purgeItems
    }

    var cleanTotalBytes: Int64 {
        cleanItems.reduce(0) { $0 + $1.byteSize }
    }

    var cleanCategories: [CleanCategory] {
        var order: [String] = []
        var buckets: [String: [ScanItem]] = [:]
        for item in cleanItems {
            let trimmed = item.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key = trimmed.isEmpty ? Self.fallbackCategory(for: item) : trimmed
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        return order.compactMap { name -> CleanCategory? in
            guard let items = buckets[name] else { return nil }
            return CleanCategory(name: name, items: items.sorted { $0.byteSize > $1.byteSize })
        }
        .sorted { $0.byteSize > $1.byteSize }
    }

    private static func fallbackCategory(for item: ScanItem) -> String {
        if item.path.localizedCaseInsensitiveContains("Caches") { return "App Caches" }
        if item.path.localizedCaseInsensitiveContains("/Logs") { return "Logs" }
        if item.path.hasSuffix(".dmg") || item.path.hasSuffix(".pkg") { return "Installers" }
        if item.path.localizedCaseInsensitiveContains(".Trash") { return "Trash" }
        return "Other"
    }

    enum AnalyzeSegment: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case map = "Map"
        case large = "Large"
        case dupes = "Dupes"
        var id: String { rawValue }
    }

    enum SoftwareSegment: String, CaseIterable, Identifiable {
        case uninstall = "Uninstall"
        case updates = "Updates"
        case startup = "Startup"
        case caches = "Caches"
        case leftovers = "Leftovers"
        case orphans = "Orphans"
        var id: String { rawValue }
    }

    /// Primary Apps tabs shown in the Mole-style chrome.
    static let appsPrimarySegments: [SoftwareSegment] = [.uninstall, .updates, .startup]

    enum AppsSort: String, CaseIterable, Identifiable {
        case name = "Name"
        case appSize = "App size"
        case lastUsed = "Last Used"
        case installed = "Installed"
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
            return cleanItems
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
        if section == .software && softwareSegment == .uninstall {
            return uninstallSelectedBytes
        }
        return currentItems.filter { selected.contains($0.path) }.reduce(0) { $0 + $1.byteSize }
    }

    var uninstallSelectedBytes: Int64 {
        apps.filter { selected.contains($0.path) }.reduce(0) { sum, app in
            let appPart = app.appBytes ?? app.byteSize
            let dataPart = alsoRemoveData ? (app.leftoverBytes ?? 0) : 0
            return sum + appPart + dataPart
        }
    }

    var sortedApps: [ScanItem] {
        let q = appsQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var list = apps
        if !q.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q)
            }
        }
        switch appsSort {
        case .name:
            return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .appSize:
            return list.sorted { ($0.appBytes ?? $0.byteSize) > ($1.appBytes ?? $1.byteSize) }
        case .lastUsed:
            return list.sorted {
                (AppMeta.lastUsed($0.path) ?? .distantPast) > (AppMeta.lastUsed($1.path) ?? .distantPast)
            }
        case .installed:
            return list.sorted {
                (AppMeta.installed($0.path) ?? .distantPast) > (AppMeta.installed($1.path) ?? .distantPast)
            }
        }
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
                // One Clean scan fills all buckets (Mole-style single review list).
                junk = try await CLIExecutor.shared.run(["junk", "--json"], as: ItemsResponse.self).items
                installers = try await CLIExecutor.shared.run(["installer", "--json"], as: ItemsResponse.self).items
                purgeItems = try await CLIExecutor.shared.run(["purge", "--json"], as: ItemsResponse.self).items
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
                // Mole-style Analyze always refreshes disk overview + folder treemap.
                overview = try await CLIExecutor.shared.run(["analyze", "overview", "--json"], as: OverviewResponse.self)
                treemap = try await CLIExecutor.shared.run(
                    ["analyze", "treemap", "--path", treemapPath, "--json"],
                    as: TreeNode.self
                )
                analyzeSelectedPath = treemap?.children?.first?.path
                if analyzeSegment == .large {
                    large = try await CLIExecutor.shared.run(["analyze", "large", "--json"], as: ItemsResponse.self).items
                } else if analyzeSegment == .dupes {
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
        var raw = Array(selected)
        if allowApps && alsoRemoveData {
            for app in apps where selected.contains(app.path) {
                for leftover in app.leftovers ?? [] {
                    raw.append(leftover.path)
                }
            }
        }
        let paths = raw.filter {
            Safety.canTrash(path: $0, safety: "review", allowApps: allowApps)
                || Safety.canTrash(path: $0, safety: "safe", allowApps: allowApps)
        }
        .filter { !Safety.isBlocked($0, allowApps: allowApps) }
        let collapsed = collapseNested(Array(Set(paths)))
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

    func selectAllClean() {
        selected = Set(cleanItems.filter { $0.safety != "blocked" && !Safety.isBlocked($0.path) }.map(\.path))
    }

    func selectRecommendedClean() {
        selectSafe()
        if selected.isEmpty {
            // Prefer review+safe caches/logs over installers when nothing marked safe.
            selected = Set(cleanItems.filter {
                $0.safety != "blocked" && !Safety.isBlocked($0.path)
                    && ($0.safety == "safe" || $0.isCacheLeftover
                        || ($0.category?.localizedCaseInsensitiveContains("cache") == true)
                        || ($0.category?.localizedCaseInsensitiveContains("log") == true))
            }.map(\.path))
        }
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

    func scanAppsQuiet() async {
        do {
            let r = try await CLIExecutor.shared.run(["apps", "--json"], as: AppsResponse.self)
            apps = r.apps
            orphans = r.orphans
        } catch {
            // keep existing list
        }
    }

    func ignoreUpdate(_ item: UpdateItem) {
        ignoredUpdateIDs.insert(item.id)
        UserDefaults.standard.set(Array(ignoredUpdateIDs), forKey: "ignoredUpdateIDs")
        statusLine = "Ignored \(item.name)"
    }

    func openUpdate(_ item: UpdateItem) {
        if item.source == "mas" {
            NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
            return
        }
        if item.source.contains("homebrew") {
            let flag = item.source.contains("cask") ? "--cask " : ""
            let script = "brew upgrade \(flag)\(item.name)"
            let src = """
            tell application "Terminal"
              activate
              do script "\(script)"
            end tell
            """
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", src]
            try? proc.run()
            statusLine = "Updating \(item.name)…"
            return
        }
        if let detail = item.detail, let url = URL(string: detail), url.scheme?.hasPrefix("http") == true {
            NSWorkspace.shared.open(url)
        }
    }

    var visibleUpdates: [UpdateItem] {
        updates.filter { !ignoredUpdateIDs.contains($0.id) }
    }

    var updatesInApp: [UpdateItem] {
        visibleUpdates.filter { ($0.group ?? "in-app") == "in-app" && $0.source != "mas" }
    }

    var updatesOutside: [UpdateItem] {
        visibleUpdates.filter { ($0.group ?? "") == "outside" || $0.source == "mas" }
    }

    /// Installed apps that are not in the outdated brew/mas list.
    var upToDateApps: [ScanItem] {
        let outdated = Set(visibleUpdates.map { $0.name.lowercased() })
        return sortedApps.filter { !outdated.contains($0.name.lowercased()) }
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
