import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var state: AppState?
    private var keepAwakeStarted: Date?
    private let menu = NSMenu()

    func install(state: AppState) {
        self.state = state
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "CleanMac")
            button.toolTip = "CleanMac"
        }
        menu.delegate = self
        item.menu = menu
        statusItem = item
        rebuildMenu()
        Task { await refreshStatus() }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let m = state?.metrics

        menu.addItem(disabled(healthTitle(m)))
        if let m {
            let cpu = Int((m.cpuPercent ?? 0).rounded())
            let memPct = m.memTotal > 0 ? Int((Double(m.memUsed) / Double(m.memTotal) * 100).rounded()) : 0
            menu.addItem(disabled("CPU \(cpu)% · Mem \(memPct)% · Disk \(ByteFormat.disk(m.diskFree)) free"))
            let top = Array((m.processes ?? []).prefix(5))
            if !top.isEmpty {
                menu.addItem(.separator())
                menu.addItem(disabled("Top CPU"))
                for p in top {
                    menu.addItem(disabled(String(format: "  %@  %.0f%%  %.0f MB", p.name, p.cpu, p.memMB)))
                }
            }
        }

        menu.addItem(.separator())
        add("Open CleanMac", #selector(openMain), "o")
        add("Refresh status", #selector(refresh), "r")
        menu.addItem(.separator())

        let awakeTitle: String
        if state?.keepAwake == true {
            let mins = keepAwakeStarted.map { Int(Date().timeIntervalSince($0) / 60) } ?? 0
            awakeTitle = "Keep Screen On · \(mins)m"
        } else {
            awakeTitle = "Keep Screen On"
        }
        add(awakeTitle, #selector(keepAwake), "")
        add("Clean screen", #selector(cleanScreen), "")

        let privacy = PrivacyStatus.summary
        if !privacy.isEmpty {
            menu.addItem(.separator())
            menu.addItem(disabled("Privacy · \(privacy)"))
        }

        menu.addItem(.separator())
        add("Quit", #selector(quit), "q")
    }

    private func add(_ title: String, _ sel: Selector, _ key: String) {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        it.target = self
        menu.addItem(it)
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.isEnabled = false
        return it
    }

    private func healthTitle(_ m: StatusSnapshot?) -> String {
        guard let m else { return "CleanMac · —" }
        let score = m.healthScore ?? 0
        let label = m.healthLabel ?? ""
        return "Health \(score) · \(label)"
    }

    @objc private func openMain() {
        NSApp.activate(ignoringOtherApps: true)
        for w in NSApp.windows where w.canBecomeKey {
            w.makeKeyAndOrderFront(nil)
            break
        }
    }

    @objc private func refresh() {
        Task { await refreshStatus() }
    }

    @objc private func keepAwake() {
        let was = state?.keepAwake ?? false
        state?.toggleKeepAwake()
        if state?.keepAwake == true, !was {
            keepAwakeStarted = Date()
        } else if state?.keepAwake != true {
            keepAwakeStarted = nil
        }
    }

    @objc private func cleanScreen() {
        state?.showCleanScreen = true
        openMain()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refreshStatus() async {
        guard let state else { return }
        let prev = state.section
        state.section = .status
        await state.scan(quiet: true)
        state.section = prev
        if let m = state.metrics, let button = statusItem?.button {
            let cpu = Int((m.cpuPercent ?? 0).rounded())
            let score = m.healthScore ?? 0
            button.title = " \(score) · \(cpu)%"
        }
    }
}
