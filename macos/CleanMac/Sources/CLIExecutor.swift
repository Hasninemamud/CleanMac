import Foundation
import Darwin
import AppKit

struct ScanItem: Identifiable, Codable, Hashable {
    var id: String { path }
    let path: String
    let name: String
    let byteSize: Int64
    let safety: String
    var category: String?
    var explanation: String?
    var modifiedAt: Double?
    var isDirectory: Bool?
    var source: String?
    var project: String?
    var orphan: Bool?
    var leftovers: [ScanItem]?
    var leftoverBytes: Int64?
    var appBytes: Int64?
    var bundleId: String?
    var kind: String?
    var root: String?

    var isCacheLeftover: Bool {
        if let category, category.localizedCaseInsensitiveContains("cache") { return true }
        if let root, root.localizedCaseInsensitiveContains("Caches") { return true }
        return path.localizedCaseInsensitiveContains("/Library/Caches/")
            || path.localizedCaseInsensitiveContains("/Caches/")
    }
}

struct CleanCategory: Identifiable {
    var id: String { name }
    let name: String
    let items: [ScanItem]

    var byteSize: Int64 { items.reduce(0) { $0 + $1.byteSize } }
    var selectable: [ScanItem] {
        items.filter { $0.safety != "blocked" && !Safety.isBlocked($0.path) }
    }
    var blurb: String {
        items.first?.explanation
            ?? "Review items before moving them to Trash."
    }
}

struct ItemsResponse: Codable {
    let items: [ScanItem]
}

struct AppsResponse: Codable {
    let apps: [ScanItem]
    let orphans: [ScanItem]
}

struct OverviewResponse: Codable {
    let totalBytes: Int64
    let freeBytes: Int64
    let usedBytes: Int64
    let categoryBytes: [String: Int64]
    let topFolders: [TopFolder]
}

struct TopFolder: Identifiable, Codable {
    var id: String { path }
    let path: String
    let name: String
    let byteSize: Int64
    let isDirectory: Bool
}

struct DupesResponse: Codable {
    let groups: [DupeGroup]
}

struct DupeGroup: Identifiable, Codable {
    var id: String { "\(byteSize)-\(files.first?.path ?? "")" }
    let byteSize: Int64
    let reclaimableBytes: Int64
    let files: [ScanItem]
}

struct OptimizeResponse: Codable {
    let actions: [OptimizeAction]
    let dryRun: Bool
}

struct OptimizeAction: Identifiable, Codable {
    let id: String
    let title: String
    let explanation: String
    let needsSudo: Bool
    let dryRunOk: Bool
    let status: String
    var detail: String?
}

struct TreeNode: Identifiable, Codable, Hashable {
    var id: String { path }
    let path: String
    let name: String
    let byteSize: Int64
    var isDirectory: Bool?
    var children: [TreeNode]?
}

struct UpdateItem: Identifiable, Codable, Hashable {
    var id: String
    let name: String
    let source: String
    var current: String?
    var latest: String?
    var detail: String?
    /// in-app | outside | current (optional; Swift may synthesize)
    var group: String?
}

struct UpdatesResponse: Codable {
    let items: [UpdateItem]
}

struct StartupItem: Identifiable, Codable, Hashable {
    var id: String
    let name: String
    let path: String
    let kind: String
    let enabled: Bool
    var detail: String?
}

struct StartupResponse: Codable {
    let items: [StartupItem]
}

struct WhitelistResponse: Codable {
    let paths: [String]
}

struct DoctorCheck: Identifiable, Codable, Hashable {
    var id: String
    let title: String
    let status: String
    let detail: String
}

struct DoctorResponse: Codable {
    let checks: [DoctorCheck]
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id: String { "\(time)-\(action)-\(paths?.first ?? "")" }
    let time: String
    let action: String
    var paths: [String]?
    var detail: String?
    var bytes: Int64?
}

struct HistoryResponse: Codable {
    let entries: [HistoryEntry]
}

struct ProcessRow: Identifiable, Codable, Hashable {
    var id: Int { pid }
    let pid: Int
    let name: String
    let cpu: Double
    let memMB: Double
    let memPct: Double
}

struct StatusSnapshot: Codable {
    let timestamp: Int64
    let hostname: String
    let numCPU: Int
    let memTotal: UInt64
    let memUsed: UInt64
    let memFree: UInt64
    let diskTotal: Int64
    let diskFree: Int64
    let diskUsed: Int64
    var loadAvg: [Double]?
    var uptimeSec: Int64?
    var model: String?
    var chip: String?
    var osVersion: String?
    var cpuPercent: Double?
    var memPressure: Double?
    var swapUsed: UInt64?
    var memApp: UInt64?
    var memWired: UInt64?
    var memCompressed: UInt64?
    var memCached: UInt64?
    var batteryPct: Int?
    var batteryState: String?
    var batteryWatts: Double?
    var batteryCycles: Int?
    var netDownKBs: Double?
    var netUpKBs: Double?
    var gpuPercent: Double?
    var thermal: String?
    var healthScore: Int?
    var healthLabel: String?
    var processes: [ProcessRow]?
}

enum CLIError: LocalizedError {
    case binaryMissing(String)
    case failed(String)
    case decode(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .binaryMissing(let p): return "cleanmac binary not found at \(p)"
        case .failed(let m): return m
        case .decode(let m): return "JSON decode: \(m)"
        case .cancelled: return "Stopped"
        }
    }
}

final class CLIExecutor: @unchecked Sendable {
    static let shared = CLIExecutor()

    private let lock = NSLock()
    private var currentProcess: Process?

    func binaryPath() -> String {
        if let res = Bundle.main.resourceURL?.appendingPathComponent("cleanmac").path,
           FileManager.default.isExecutableFile(atPath: res) {
            return res
        }
        let candidates = [
            FileManager.default.currentDirectoryPath + "/bin/cleanmac",
            NSHomeDirectory() + "/bin/cleanmac",
            "/usr/local/bin/cleanmac",
            "/opt/homebrew/bin/cleanmac",
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
            return c
        }
        let dev = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("bin/cleanmac").path
        return dev
    }

    func cancel() {
        lock.lock()
        let proc = currentProcess
        lock.unlock()
        proc?.terminate()
    }

    func run<T: Decodable>(_ args: [String], as type: T.Type) async throws -> T {
        let bin = binaryPath()
        guard FileManager.default.isExecutableFile(atPath: bin) else {
            throw CLIError.binaryMissing(bin)
        }
        let data = try await runRaw([bin] + args)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CLIError.decode(error.localizedDescription)
        }
    }

    private func runRaw(_ argv: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: argv[0])
                proc.arguments = Array(argv.dropFirst())
                let out = Pipe()
                let err = Pipe()
                proc.standardOutput = out
                proc.standardError = err

                self.lock.lock()
                self.currentProcess = proc
                self.lock.unlock()

                do {
                    try proc.run()
                    proc.waitUntilExit()

                    self.lock.lock()
                    if self.currentProcess === proc { self.currentProcess = nil }
                    self.lock.unlock()

                    if proc.terminationReason == .uncaughtSignal || proc.terminationStatus == 15 || proc.terminationStatus == SIGTERM {
                        cont.resume(throwing: CLIError.cancelled)
                        return
                    }
                    let data = out.fileHandleForReading.readDataToEndOfFile()
                    if proc.terminationStatus != 0 {
                        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
                            ?? "exit \(proc.terminationStatus)"
                        let trimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
                        cont.resume(throwing: CLIError.failed(trimmed.isEmpty ? "exit \(proc.terminationStatus)" : trimmed))
                        return
                    }
                    cont.resume(returning: data)
                } catch {
                    self.lock.lock()
                    if self.currentProcess === proc { self.currentProcess = nil }
                    self.lock.unlock()
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

enum ByteFormat {
    /// Binary (1024) — memory, file sizes.
    static func string(_ n: Int64) -> String { format(n, base: 1024) }

    /// Decimal (1000) — disk capacity to match macOS System Settings.
    static func disk(_ n: Int64) -> String { format(n, base: 1000) }

    private static func format(_ n: Int64, base: Double) -> String {
        if Double(n) < base { return "\(n) B" }
        let units = ["KB", "MB", "GB", "TB"]
        var v = Double(n) / base
        var i = 0
        while v >= base && i < units.count - 1 {
            v /= base
            i += 1
        }
        if v >= 10 || i == 0 {
            return String(format: "%.0f %@", v, units[i])
        }
        return String(format: "%.1f %@", v, units[i])
    }
}

enum AppMeta {
    static func version(_ path: String) -> String? {
        Bundle(url: URL(fileURLWithPath: path))?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    static func lastUsed(_ path: String) -> Date? {
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.contentAccessDateKey])).flatMap(\.contentAccessDate)
            ?? (try? url.resourceValues(forKeys: [.contentModificationDateKey])).flatMap(\.contentModificationDate)
    }

    static func installed(_ path: String) -> Date? {
        (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.creationDateKey])).flatMap(\.creationDate)
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "unknown" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "active today" }
        if days == 1 { return "active 1 day ago" }
        if days < 30 { return "active \(days) days ago" }
        let months = max(1, days / 30)
        if months < 12 { return "active \(months) mo ago" }
        return "active \(months / 12) yr ago"
    }

    static func icon(_ path: String) -> NSImage {
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 40, height: 40)
        return img
    }
}
