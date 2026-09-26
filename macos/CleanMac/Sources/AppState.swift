import Foundation
import AppKit

@Observable
@MainActor
final class AppState {
    var section: NavSection = .clean
    var cleanSegment: CleanSegment = .junk
    var analyzeSegment: AnalyzeSegment = .overview
    var statusLine = "Ready"
    var busy = false
    var errorMessage: String?
    var selected = Set<String>()
    var confirmTrash = false

    var junk: [ScanItem] = []
    var installers: [ScanItem] = []
    var purgeItems: [ScanItem] = []
    var apps: [ScanItem] = []
    var orphans: [ScanItem] = []
    var overview: OverviewResponse?
    var large: [ScanItem] = []
    var dupes: [DupeGroup] = []
    var optimizeActions: [OptimizeAction] = []
    var metrics: StatusSnapshot?

    enum NavSection: String, CaseIterable, Identifiable {
        case clean = "Clean"
        case apps = "Apps"
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
        case large = "Large"
        case dupes = "Dupes"
        var id: String { rawValue }
    }

    var currentItems: [ScanItem] {
        switch section {
        case .clean:
            switch cleanSegment {
            case .junk: return junk
            case .installers: return installers
            case .purge: return purgeItems
            }
        case .apps:
            return orphans + apps.flatMap { app in
                var rows = [app]
                rows.append(contentsOf: app.leftovers ?? [])
                return rows
            }
        case .analyze:
            switch analyzeSegment {
            case .overview: return []
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

    func scan() async {
        busy = true
        errorMessage = nil
        statusLine = "Scanning…"
        defer { busy = false }
        do {
            switch section {
            case .clean:
                switch cleanSegment {
                case .junk:
                    let r = try await CLIExecutor.shared.run(["junk", "--json"], as: ItemsResponse.self)
                    junk = r.items
                case .installers:
                    let r = try await CLIExecutor.shared.run(["installer", "--json"], as: ItemsResponse.self)
                    installers = r.items
                case .purge:
                    let r = try await CLIExecutor.shared.run(["purge", "--json"], as: ItemsResponse.self)
                    purgeItems = r.items
                }
            case .apps:
                let r = try await CLIExecutor.shared.run(["apps", "--json"], as: AppsResponse.self)
                apps = r.apps
                orphans = r.orphans
            case .analyze:
                switch analyzeSegment {
                case .overview:
                    overview = try await CLIExecutor.shared.run(["analyze", "overview", "--json"], as: OverviewResponse.self)
                case .large:
                    let r = try await CLIExecutor.shared.run(["analyze", "large", "--json"], as: ItemsResponse.self)
                    large = r.items
                case .dupes:
                    let r = try await CLIExecutor.shared.run(["analyze", "dupes", "--json"], as: DupesResponse.self)
                    dupes = r.groups
                    selected = Set(r.groups.flatMap { Array($0.files.dropFirst()).map(\.path) })
                }
            case .optimize:
                let r = try await CLIExecutor.shared.run(["optimize", "--dry-run", "--json"], as: OptimizeResponse.self)
                optimizeActions = r.actions
            case .status:
                metrics = try await CLIExecutor.shared.run(["status", "--json"], as: StatusSnapshot.self)
            }
            statusLine = "Done"
            if section != .analyze || analyzeSegment != .dupes {
                selected.removeAll()
            }
        } catch {
            errorMessage = error.localizedDescription
            statusLine = "Error"
        }
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
            errorMessage = error.localizedDescription
        }
    }

    func trashSelected() async {
        let allowApps = section == .apps
        let paths = selected.filter { Safety.canTrash(path: $0, safety: "review", allowApps: allowApps) || Safety.canTrash(path: $0, safety: "safe", allowApps: allowApps) }
            .filter { !Safety.isBlocked($0, allowApps: allowApps) }
        let collapsed = collapseNested(Array(paths))
        var ok = 0
        var fail = 0
        for p in collapsed {
            do {
                var resulting: NSURL?
                try FileManager.default.trashItem(at: URL(fileURLWithPath: p), resultingItemURL: &resulting)
                ok += 1
                selected.remove(p)
            } catch {
                fail += 1
            }
        }
        statusLine = "Trashed \(ok)" + (fail > 0 ? ", \(fail) failed" : "")
        confirmTrash = false
        await scan()
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func selectSafe() {
        selected = Set(currentItems.filter { $0.safety == "safe" }.map(\.path))
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
