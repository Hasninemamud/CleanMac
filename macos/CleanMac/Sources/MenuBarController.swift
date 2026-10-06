import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var state: AppState?
    private var keepAwakeStarted: Date?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    func install(state: AppState) {
        self.state = state
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "CleanMac")
            button.imagePosition = .imageLeading
            button.toolTip = "CleanMac"
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        Task { await refreshStatus() }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover?.isShown == true {
            closePopover()
            return
        }
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }
        Task { @MainActor in
            await refreshStatus()
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem?.button else { return }
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentSize = NSSize(width: 320, height: 420)
        pop.contentViewController = NSHostingController(rootView: popoverRoot())
        popover = pop
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func popoverRoot() -> MenuBarPopoverView {
        MenuBarPopoverView(
            metrics: state?.metrics,
            keepAwake: state?.keepAwake ?? false,
            keepAwakeMinutes: keepAwakeMinutes(),
            privacy: PrivacyStatus.summary,
            onOpen: { [weak self] in self?.openMain(); self?.closePopover() },
            onRefresh: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    await self.refreshStatus()
                    self.popover?.contentViewController = NSHostingController(rootView: self.popoverRoot())
                }
            },
            onKeepAwake: { [weak self] in
                guard let self else { return }
                self.keepAwake()
                self.popover?.contentViewController = NSHostingController(rootView: self.popoverRoot())
            },
            onCleanScreen: { [weak self] in self?.cleanScreen(); self?.closePopover() },
            onQuit: { [weak self] in self?.quit() }
        )
    }

    private func closePopover() {
        popover?.performClose(nil)
        popover = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open CleanMac", action: #selector(openMain), keyEquivalent: "o")
        menu.addItem(withTitle: "Refresh status", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Keep Screen On", action: #selector(keepAwake), keyEquivalent: "")
        menu.addItem(withTitle: "Clean screen", action: #selector(cleanScreen), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        for it in menu.items { it.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
    }

    private func keepAwakeMinutes() -> Int {
        guard state?.keepAwake == true, let start = keepAwakeStarted else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start) / 60))
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

// MARK: - Popover UI

private struct MenuBarPopoverView: View {
    let metrics: StatusSnapshot?
    let keepAwake: Bool
    let keepAwakeMinutes: Int
    let privacy: String
    let onOpen: () -> Void
    let onRefresh: () -> Void
    let onKeepAwake: () -> Void
    let onCleanScreen: () -> Void
    let onQuit: () -> Void

    private var score: Int { metrics?.healthScore ?? 0 }
    private var label: String { metrics?.healthLabel ?? "—" }
    private var cpu: Double { metrics?.cpuPercent ?? 0 }
    private var gpu: Double { metrics?.gpuPercent ?? 0 }
    private var memPct: Double {
        guard let m = metrics, m.memTotal > 0 else { return 0 }
        return Double(m.memUsed) / Double(m.memTotal) * 100
    }
    private var healthColor: Color {
        if score >= 88 { return Theme.ok }
        if score >= 72 { return Theme.Feature.status }
        if score >= 55 { return Theme.warn }
        return Theme.danger
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(14)

            Rectangle().fill(Theme.line).frame(height: 1)

            if metrics != nil {
                meters
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .animation(Theme.Motion.meter, value: metrics?.timestamp)

                Rectangle().fill(Theme.line).frame(height: 1)

                processList
                    .padding(14)
            } else {
                Text("Loading live metrics…")
                    .font(Theme.Typeface.body(12))
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }

            Rectangle().fill(Theme.line).frame(height: 1)

            actions
                .padding(10)
        }
        .frame(width: 320)
        .background(
            ZStack {
                Theme.Feature.pageBG(for: .status)
                RadialGradient(
                    colors: [Theme.Feature.status.opacity(0.14), .clear],
                    center: UnitPoint(x: 0.85, y: 0.1),
                    startRadius: 4,
                    endRadius: 220
                )
            }
        )
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [healthColor.opacity(0.45), healthColor.opacity(0.12)],
                            center: .center, startRadius: 2, endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)
                Text("\(score)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Health")
                    .font(Theme.Typeface.caption())
                    .foregroundColor(Theme.muted)
                Text(label)
                    .font(Theme.Typeface.title(18))
                    .foregroundColor(healthColor)
                    .contentTransition(.opacity)
                if let m = metrics {
                    Text(m.chip ?? m.model ?? "Mac")
                        .font(Theme.Typeface.body(11))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var meters: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                meterCard("CPU", cpu, tint: cpu > 70 ? Theme.warn : Theme.Feature.clean)
                meterCard("GPU", gpu, tint: gpu > 70 ? Theme.warn : Theme.Feature.analyze)
            }
            HStack(spacing: 8) {
                meterCard("Mem", memPct, tint: memPct > 85 ? Theme.warn : Theme.ok)
                VStack(alignment: .leading, spacing: 6) {
                    Text("DISK")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(Theme.muted)
                    Text(ByteFormat.disk(metrics?.diskFree ?? 0))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("free of \(ByteFormat.disk(metrics?.diskTotal ?? 0))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Theme.Feature.panelFill(for: .status))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(Theme.line, lineWidth: 1)
                )
            }
        }
    }

    private func meterCard(_ title: String, _ pct: Double, tint: Color) -> some View {
        let clamped = min(max(pct, 0), 100)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundColor(Theme.muted)
            Text("\(Int(clamped.rounded()))%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Theme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line.opacity(0.7))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * clamped / 100))
                        .animation(Theme.Motion.meter, value: clamped)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Theme.Feature.panelFill(for: .status))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var processList: some View {
        let top = Array((metrics?.processes ?? []).prefix(5))
        return VStack(alignment: .leading, spacing: 8) {
            Text("TOP CPU")
                .font(Theme.Typeface.micro())
                .tracking(0.6)
                .foregroundColor(Theme.muted)
            if top.isEmpty {
                Text("No processes")
                    .font(Theme.Typeface.body(12))
                    .foregroundColor(Theme.muted)
            } else {
                ForEach(Array(top.enumerated()), id: \.element.id) { idx, p in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(p.cpu >= 30 ? Theme.warn : Theme.muted.opacity(0.45))
                            .frame(width: 6, height: 6)
                        Text(p.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(String(format: "%.0f%%", p.cpu))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(p.cpu >= 30 ? Theme.warn : Theme.muted)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .frame(width: 36, alignment: .trailing)
                        Text(String(format: "%.0f MB", p.memMB))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.muted)
                            .monospacedDigit()
                            .frame(width: 54, alignment: .trailing)
                    }
                    .listAppear(index: idx)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 4) {
            actionRow("Open CleanMac", "macwindow", shortcut: "⌘O", action: onOpen)
            actionRow("Refresh status", "arrow.clockwise", shortcut: "⌘R", action: onRefresh)
            actionRow(
                keepAwake ? (keepAwakeMinutes == 0 ? "Keep Screen On · On" : "Keep Screen On · \(keepAwakeMinutes)m") : "Keep Screen On",
                "cup.and.saucer.fill",
                shortcut: nil,
                tint: keepAwake ? healthColor : nil,
                action: onKeepAwake
            )
            actionRow("Clean screen", "rectangle.dashed", shortcut: nil, action: onCleanScreen)

            Text("Privacy · \(privacy)")
                .font(Theme.Typeface.micro())
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 4)
            actionRow("Quit CleanMac", "power", shortcut: "⌘Q", action: onQuit)
        }
    }

    private func actionRow(_ title: String, _ symbol: String, shortcut: String?, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint ?? Theme.muted)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(PressableCapsuleStyle())
    }
}
