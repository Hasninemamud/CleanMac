import Foundation

enum Safety {
    static let blockedPrefixes = [
        "/System", "/usr", "/bin", "/sbin",
        "/private/var/db", "/Library/Apple",
        "/Library/OSAnalytics", "/Library/Updates",
    ]

    static let blockedHomeSuffixes = [
        "/Library/Keychains", "/Library/Mail", "/Library/Messages",
        "/Library/Calendars", "/Library/Accounts", "/Library/IdentityServices",
        "/Library/Cookies", "/Library/Suggestions", "/Library/Shortcuts",
        "/Library/Application Support/AddressBook",
        "/Library/Application Support/CallHistoryDB",
        "/Library/Application Support/com.apple.TCC",
        "/Pictures/Photos Library.photoslibrary",
        "/Music/Music", "/.ssh", "/.gnupg",
    ]

    static let blockedCacheNames: Set<String> = [
        "CloudKit", "com.apple.HomeKit", "FamilyCircle", "com.apple.findmy",
        "com.apple.Safari.SafeBrowsing", "com.apple.assistantd",
        "com.apple.ap.adprivacyd", "com.apple.containermanagerd", "PassKit",
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
        for suf in blockedHomeSuffixes {
            if s.hasSuffix(suf) || s.contains(suf + "/") { return true }
        }
        let base = (s as NSString).lastPathComponent
        if blockedCacheNames.contains(base) { return true }
        let parts = s.split(separator: "/").map(String.init)
        for i in 0..<(parts.count - 1) {
            if parts[i] == "Caches" && blockedCacheNames.contains(parts[i + 1]) {
                return true
            }
        }
        if !allowApps && isAppBundle(s) { return true }
        return false
    }

    static func canTrash(path: String, safety: String, allowApps: Bool = false) -> Bool {
        safety != "blocked" && !isBlocked(path, allowApps: allowApps)
    }

    /// Junk/cache cleanup permanently removes. Uninstall and Analyze keep Trash for recoverability.
    static func usesPermanentDelete(isUninstall: Bool, isAnalyze: Bool) -> Bool {
        !isUninstall && !isAnalyze
    }
}
