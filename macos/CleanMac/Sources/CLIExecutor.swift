import Foundation

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
}

enum CLIError: LocalizedError {
    case binaryMissing(String)
    case failed(String)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .binaryMissing(let p): return "cleanmac binary not found at \(p)"
        case .failed(let m): return m
        case .decode(let m): return "JSON decode: \(m)"
        }
    }
}

final class CLIExecutor {
    static let shared = CLIExecutor()

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
        // Dev: sibling of Package.swift build
        let dev = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("bin/cleanmac").path
        return dev
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
                do {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: argv[0])
                    proc.arguments = Array(argv.dropFirst())
                    let out = Pipe()
                    let err = Pipe()
                    proc.standardOutput = out
                    proc.standardError = err
                    try proc.run()
                    proc.waitUntilExit()
                    let data = out.fileHandleForReading.readDataToEndOfFile()
                    if proc.terminationStatus != 0 {
                        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "exit \(proc.terminationStatus)"
                        cont.resume(throwing: CLIError.failed(msg))
                        return
                    }
                    cont.resume(returning: data)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

enum ByteFormat {
    static func string(_ n: Int64) -> String {
        if n < 1024 { return "\(n) B" }
        let units = ["KB", "MB", "GB", "TB"]
        var v = Double(n) / 1024
        var i = 0
        while v >= 1024 && i < units.count - 1 {
            v /= 1024
            i += 1
        }
        if v >= 10 || i == 0 {
            return String(format: "%.0f %@", v, units[i])
        }
        return String(format: "%.1f %@", v, units[i])
    }
}
