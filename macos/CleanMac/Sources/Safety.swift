import Foundation

enum Safety {
    static let blockedPrefixes = [
        "/System", "/usr", "/bin", "/sbin",
        "/private/var/db", "/Library/Apple",
        "/Library/OSAnalytics", "/Library/Updates",
    ]

    static func standardize(_ path: String) -> String {
        var p = (path as NSString).standardizingPath
        if p.count > 1 && p.hasSuffix("/") { p = String(p.dropLast()) }
        return p
    }

    static func isAppBundle(_ path: String) -> Bool {
        let s = standardize(path)
        return s.hasPrefix("/Applications/") && (s.hasSuffix(".app") || s.contains(".app/"))
    }

    static func isBlocked(_ path: String, allowApps: Bool = false) -> Bool {
        let s = standardize(path)
        if s == "/" || s == "/private" { return true }
        for prefix in blockedPrefixes {
            if s == prefix || s.hasPrefix(prefix + "/") { return true }
        }
        if !allowApps && isAppBundle(s) { return true }
        return false
    }

    static func canTrash(path: String, safety: String, allowApps: Bool = false) -> Bool {
        safety != "blocked" && !isBlocked(path, allowApps: allowApps)
    }
}
