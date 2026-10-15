import AppKit
import Foundation

/// macOS privacy — Full Disk Access stops repeated per-folder "Allow" prompts during scans.
enum Permissions {
    private static let suppressFDAReminderKey = "suppressFullDiskAccessReminder"

    /// Heuristic: without FDA, `~/Library/Mail` is usually unreadable on modern macOS.
    static func hasFullDiskAccess() -> Bool {
        let probe = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Mail")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: probe, isDirectory: &isDir) else {
            return true
        }
        return FileManager.default.isReadableFile(atPath: probe)
    }

    static var shouldRemindForFullDiskAccess: Bool {
        !UserDefaults.standard.bool(forKey: suppressFDAReminderKey) && !hasFullDiskAccess()
    }

    static func suppressFullDiskAccessReminder() {
        UserDefaults.standard.set(true, forKey: suppressFDAReminderKey)
    }

    static func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
