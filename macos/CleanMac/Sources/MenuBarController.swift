import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var state: AppState?

    func install(state: AppState) {
        self.state = state
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "CleanMac")
            button.toolTip = "CleanMac"
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open CleanMac", action: #selector(openMain), keyEquivalent: "o")
        menu.addItem(withTitle: "Refresh status", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Keep awake", action: #selector(keepAwake), keyEquivalent: "")
        menu.addItem(withTitle: "Clean screen", action: #selector(cleanScreen), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        for it in menu.items {
            it.target = self
        }
        item.menu = menu
        statusItem = item
        Task { await refreshStatus() }
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
        state?.toggleKeepAwake()
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
