import AppKit
import SwiftUI

/// Live HUD state — one instance; never rebuild NSHostingController on poll.
@Observable
@MainActor
private final class MenuBarHUDModel {
    var metrics: StatusSnapshot?
    var keepAwake = false
    var keepAwakeMinutes = 0
    var cleanHistory = CleanHistoryStats()
    var histCPU: [Double] = []
    var histGPU: [Double] = []
    var histMem: [Double] = []
    var histDisk: [Double] = []
    var histNet: [Double] = []
    var refreshing = false
}

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var state: AppState?
    private var keepAwakeStarted: Date?
    private var popover: NSPopover?
    private var hosting: NSHostingController<MenuBarPopoverView>?
    private var liveTimer: Timer?
    private let hud = MenuBarHUDModel()

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
        syncChrome()
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
        // Open immediately with cached metrics — refresh in background (no blink wait).
        openPopover()
        Task { await refreshStatus() }
    }

    private func openPopover() {
        guard let button = statusItem?.button else { return }
        syncChrome()
        if popover == nil {
            let pop = NSPopover()
            pop.behavior = .transient
            pop.animates = true
            pop.contentSize = NSSize(width: 380, height: 720)
            let root = MenuBarPopoverView(
                model: hud,
                onOpen: { [weak self] in self?.openMain(); self?.closePopover() },
                onRefresh: { [weak self] in Task { await self?.refreshStatus() } },
                onKeepAwake: { [weak self] in
                    self?.keepAwake()
                    self?.syncChrome()
                },
                onCleanScreen: { [weak self] in self?.cleanScreen(); self?.closePopover() },
                onQuitProcess: { [weak self] pid in self?.state?.quitProcess(pid: pid) },
                onForceQuitProcess: { [weak self] pid in self?.state?.forceQuitProcess(pid: pid) },
                onCopyPath: { [weak self] path in self?.state?.copyProcessPath(path) },
                onQuit: { [weak self] in self?.quit() }
            )
            let host = NSHostingController(rootView: root)
            hosting = host
            pop.contentViewController = host
            popover = pop
        }
        guard let pop = popover, !pop.isShown else { return }
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        liveTimer?.invalidate()
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.popover?.isShown == true else { return }
                await self.refreshStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        liveTimer = timer
    }

    private func closePopover() {
        liveTimer?.invalidate()
        liveTimer = nil
        popover?.performClose(nil)
        // Keep popover + hosting alive so the next open is instant and doesn't remount.
    }

    private func syncChrome() {
        hud.keepAwake = state?.keepAwake ?? false
        hud.keepAwakeMinutes = keepAwakeMinutes()
        hud.cleanHistory = CleanHistoryStats.load()
        if let m = state?.metrics {
            applyMetrics(m, animated: false)
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
        hud.keepAwake = state?.keepAwake ?? false
        hud.keepAwakeMinutes = keepAwakeMinutes()
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
        if hud.refreshing { return }
        hud.refreshing = true
        defer { hud.refreshing = false }
        await state.fetchStatusMetrics()
        if let m = state.metrics {
            applyMetrics(m, animated: true)
            if let button = statusItem?.button {
                let cpu = Int((m.cpuPercent ?? 0).rounded())
                let score = m.healthScore ?? 0
                button.title = " \(score) · \(cpu)%"
            }
        }
        hud.keepAwake = state.keepAwake
        hud.keepAwakeMinutes = keepAwakeMinutes()
        hud.cleanHistory = CleanHistoryStats.load()
    }

    private func applyMetrics(_ m: StatusSnapshot, animated: Bool) {
        let memT = m.memTotal > 0 ? Double(m.memTotal) : Double(ProcessInfo.processInfo.physicalMemory)
        let memR = memT > 0 ? min(Double(m.memUsed) / memT, 1) : 0
        let diskR = m.diskTotal > 0 ? min(Double(m.diskUsed) / Double(m.diskTotal), 1) : 0
        let cpuV = min((m.cpuPercent ?? 0) / 100, 1)
        let gpuV = min((m.gpuPercent ?? 0) / 100, 1)
        let netV = min(((m.netDownKBs ?? 0) + (m.netUpKBs ?? 0)) / 800, 1)
        // Seed a short flat baseline so first open isn't an empty/jagged single-point chart.
        func grow(_ hist: [Double], _ v: Double) -> [Double] {
            var a = hist.isEmpty ? Array(repeating: v, count: 8) : hist
            a.append(v)
            trim(&a)
            return a
        }
        let cpu = grow(hud.histCPU, cpuV)
        let gpu = grow(hud.histGPU, gpuV)
        let mem = grow(hud.histMem, memR)
        let disk = grow(hud.histDisk, diskR)
        let net = grow(hud.histNet, netV)

        let apply = {
            self.hud.metrics = m
            self.hud.histCPU = cpu
            self.hud.histGPU = gpu
            self.hud.histMem = mem
            self.hud.histDisk = disk
            self.hud.histNet = net
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.28)) { apply() }
        } else {
            apply()
        }
    }

    private func trim(_ a: inout [Double]) {
        if a.count > 24 { a.removeFirst(a.count - 24) }
    }
}

// MARK: - Clean history (ops log — only real data)

private struct CleanHistoryStats {
    var cleanedBytes: Int64 = 0
    var uninstalled: Int = 0
    var optimized: Int = 0
    var hasData: Bool { cleanedBytes > 0 || uninstalled > 0 || optimized > 0 }

    static func load() -> CleanHistoryStats {
        let path = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Logs/CleanMac/operations.log")
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return CleanHistoryStats()
        }
        var s = CleanHistoryStats()
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let action = obj["action"] as? String else { continue }
            let bytes = (obj["bytes"] as? NSNumber)?.int64Value ?? 0
            switch action {
            case "delete":
                s.cleanedBytes += bytes
            case "trash":
                s.uninstalled += 1
            case "optimize":
                s.optimized += 1
            default:
                break
            }
        }
        return s
    }
}

// MARK: - Popover UI

private enum PopDash {
    static let blue = Color(red: 0.45, green: 0.72, blue: 0.78)
    static let amber = Color(red: 0.96, green: 0.62, blue: 0.22)
    static let teal = Color(red: 0.55, green: 0.78, blue: 0.55)
    static let green = Color(red: 0.72, green: 0.83, blue: 0.36)
    static let glass = Color(red: 0.14, green: 0.12, blue: 0.09)
}

private struct MenuBarPopoverView: View {
    @Bindable var model: MenuBarHUDModel
    let onOpen: () -> Void
    let onRefresh: () -> Void
    let onKeepAwake: () -> Void
    let onCleanScreen: () -> Void
    let onQuitProcess: (Int) -> Void
    let onForceQuitProcess: (Int) -> Void
    let onCopyPath: (String?) -> Void
    let onQuit: () -> Void

    private var metrics: StatusSnapshot? { model.metrics }
    private var keepAwake: Bool { model.keepAwake }
    private var keepAwakeMinutes: Int { model.keepAwakeMinutes }
    private var cleanHistory: CleanHistoryStats { model.cleanHistory }
    private var histCPU: [Double] { model.histCPU }
    private var histGPU: [Double] { model.histGPU }
    private var histMem: [Double] { model.histMem }
    private var histDisk: [Double] { model.histDisk }
    private var histNet: [Double] { model.histNet }

    private var score: Int { metrics?.healthScore ?? 0 }
    private var label: String { metrics?.healthLabel ?? "—" }
    private var healthColor: Color {
        if score >= 88 { return PopDash.green }
        if score >= 72 { return Theme.Feature.status }
        if score >= 55 { return PopDash.amber }
        return Theme.danger
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                header
                if let m = metrics {
                    metricGrid(m)
                    if showBattery(m) { batteryCard(m) }
                    processTable(m)
                } else {
                    Text("Loading live metrics…")
                        .font(Theme.Typeface.body(12))
                        .foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                footer
            }
            .padding(14)
        }
        .frame(width: 380)
        .frame(maxHeight: 700)
        .background(
            ZStack {
                Theme.bg
                Theme.surface.opacity(Theme.useDark ? 0.55 : 0.92)
                RadialGradient(
                    colors: [PopDash.amber.opacity(Theme.useDark ? 0.10 : 0.06), .clear],
                    center: UnitPoint(x: 0.9, y: 0.05),
                    startRadius: 2,
                    endRadius: 260
                )
            }
        )
        .preferredColorScheme(Theme.useDark ? .dark : .light)
        .animation(.easeInOut(duration: 0.28), value: score)
        .animation(.easeInOut(duration: 0.28), value: metrics?.cpuPercent)
        .animation(.easeInOut(duration: 0.28), value: metrics?.gpuPercent)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        RadialGradient(
                            colors: [PopDash.amber, Color(red: 0.85, green: 0.35, blue: 0.12)],
                            center: .center, startRadius: 1, endRadius: 14
                        )
                    )
                    .shadow(color: PopDash.amber.opacity(0.45), radius: 8)
                Text("\(score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(label)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.ink.opacity(0.88))
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .rotationEffect(.degrees(model.refreshing ? 360 : 0))
                        .animation(
                            model.refreshing
                                ? .linear(duration: 0.7).repeatForever(autoreverses: false)
                                : .default,
                            value: model.refreshing
                        )
                        .padding(6)
                        .background(Circle().fill(Theme.line.opacity(0.6)))
                }
                .disabled(model.refreshing)
                .buttonStyle(.plain)
                .help("Refresh")
            }
            if let m = metrics {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chip(shortChip(m))
                        let gb = Int(Double(effectiveMem(m)) / 1_073_741_824)
                        if gb > 0 { chip("\(gb) GB") }
                        if let os = m.osVersion, !os.isEmpty { chip("macOS \(os)") }
                        chip(uptimeLine(m))
                    }
                }
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Theme.ink.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Theme.line.opacity(0.5), lineWidth: 1)
            )
    }

    // MARK: Metric grid

    private func metricGrid(_ m: StatusSnapshot) -> some View {
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        let cpu = m.cpuPercent ?? 0
        let gpu = m.gpuPercent ?? 0
        let memPct = memRatio(m) * 100
        let pressure = Int(((m.memPressure ?? memRatio(m)) * 100).rounded())
        let netTotal = (m.netDownKBs ?? 0) + (m.netUpKBs ?? 0)
        let thermalTint: Color = {
            switch (m.thermal ?? "Normal").lowercased() {
            case "warm": return Theme.danger
            case "elevated": return PopDash.amber
            default: return PopDash.green
            }
        }()

        return LazyVGrid(columns: cols, spacing: 8) {
            miniCard(
                icon: "cpu", title: "CPU", tint: cpu > 70 ? PopDash.amber : PopDash.green,
                badge: estTemp(cpu), primary: pct(cpu),
                footer: "\((m.thermal ?? "normal").lowercased()) · Load \(loadText(m))/\(m.numCPU)",
                history: histCPU, chart: .bars
            )
            miniCard(
                icon: "square.3.layers.3d", title: "GPU", tint: PopDash.amber,
                badge: estTemp(gpu), primary: pct(gpu),
                footer: gpuFooter(m, gpu: gpu),
                history: histGPU, chart: .line
            )
            miniCard(
                icon: "memorychip", title: "MEM", tint: memPct > 85 ? PopDash.amber : PopDash.green,
                badge: "PRS \(pressure)%", primary: pct(memPct),
                footer: "\(ByteFormat.string(Int64(m.memUsed))) / \(ByteFormat.string(Int64(effectiveMem(m))))",
                history: histMem, chart: .bar
            )
            miniCard(
                icon: "internaldrive", title: "Disk", tint: PopDash.blue,
                badge: ByteFormat.disk(m.diskTotal), primary: ByteFormat.disk(m.diskFree),
                footer: "\(ByteFormat.disk(m.diskUsed)) used · \(Int((diskRatio(m) * 100).rounded()))%",
                history: histDisk, chart: .bar
            )
            miniCard(
                icon: "wifi", title: "Network", tint: PopDash.blue,
                badge: m.netIface ?? "Network", primary: rate(netTotal),
                footer: "↑ \(rateShort(m.netUpKBs ?? 0)) · ↓ \(rateShort(m.netDownKBs ?? 0))",
                history: histNet, chart: .line
            )
            miniCard(
                icon: "thermometer.medium", title: "Thermal", tint: thermalTint,
                badge: m.thermal ?? "Normal", primary: estTemp(cpu),
                footer: "GPU \(estTemp(gpu)) · \(shortChip(m))",
                history: [min(cpu / 100, 1)], chart: .bar
            )
        }
    }

    private enum MiniChart { case bars, line, bar }

    private func miniCard(
        icon: String, title: String, tint: Color, badge: String, primary: String,
        footer: String, history: [Double], chart: MiniChart
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Spacer(minLength: 2)
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            .foregroundColor(tint)

            Text(primary)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            Group {
                switch chart {
                case .bars:
                    BarChart(values: history, color: tint)
                case .line:
                    Sparkline(values: history, color: tint, lineWidth: 1.5)
                case .bar:
                    GeometryReader { geo in
                        let p = min(max(history.last ?? 0, 0), 1)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line.opacity(0.8))
                            Capsule()
                                .fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(4, geo.size.width * p))
                                .animation(Theme.Motion.meter, value: p)
                        }
                    }
                }
            }
            .frame(height: chart == .bar ? 6 : 26)
            .clipped()

            Text(footer)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.middle)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(cardBG)
    }

    // MARK: Battery

    private func showBattery(_ m: StatusSnapshot) -> Bool {
        let desktop = m.batteryState == "Desktop"
            || ((m.batteryPct ?? 0) == 0 && (m.batteryState == "Unknown" || m.batteryState == nil))
        return !desktop
    }

    private func batteryCard(_ m: StatusSnapshot) -> some View {
        let pctVal = Double(m.batteryPct ?? 0) / 100
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "battery.100")
                        .font(.system(size: 11, weight: .bold))
                    Text("Battery")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(PopDash.green)
                Spacer()
                if let h = m.batteryHealth, h > 0 {
                    Text("\(h)% Health")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(m.batteryPct ?? 0)%")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.ink)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(m.batteryState ?? "—")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.muted)
                        if let w = m.batteryWatts, w > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(String(format: "%.0fW", w))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(PopDash.amber)
                        }
                    }
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 5).frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: pctVal)
                        .stroke(PopDash.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                        .animation(Theme.Motion.meter, value: pctVal)
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.ink)
                }
            }

            if let top = (m.processes ?? []).first {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(PopDash.amber)
                    Text("Top drain \(top.name) · \(String(format: "%.1f", top.cpu))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(cardBG)
    }

    // MARK: Processes

    private func processTable(_ m: StatusSnapshot) -> some View {
        let top = Array((m.processes ?? []).prefix(5))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.muted)
                Text("Top Processes")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.ink)
                Spacer()
                Text("Memory")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 64, alignment: .trailing)
                Text("% CPU")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 44, alignment: .trailing)
                Color.clear.frame(width: 18)
            }

            if top.isEmpty {
                Text("No processes")
                    .font(Theme.Typeface.body(12))
                    .foregroundColor(Theme.muted)
            } else {
                ForEach(top) { p in
                    HStack(spacing: 8) {
                        Text(p.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(memLabel(p.memMB))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.muted)
                            .monospacedDigit()
                            .frame(width: 64, alignment: .trailing)
                        Text(String(format: "%.1f", p.cpu))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(p.cpu >= 40 ? Theme.danger : Theme.muted)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .frame(width: 44, alignment: .trailing)
                        Menu {
                            Button("Copy path") { onCopyPath(p.path) }
                            Divider()
                            Button("Quit", role: .destructive) { onQuitProcess(p.pid) }
                            Button("Force Quit", role: .destructive) { onForceQuitProcess(p.pid) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.muted)
                                .frame(width: 18, height: 16)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(12)
        .background(cardBG)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                privacyIcons
                Spacer(minLength: 0)
                footerBtn(
                    keepAwake ? (keepAwakeMinutes == 0 ? "Awake" : "Awake \(keepAwakeMinutes)m") : "Awake",
                    "cup.and.saucer.fill",
                    tint: keepAwake ? PopDash.amber : Theme.muted,
                    action: onKeepAwake
                )
                footerBtn("Screen", "wand.and.stars", tint: Theme.muted, action: onCleanScreen)
            }

            if cleanHistory.hasData {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(PopDash.amber)
                        Text("Clean History")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.ink)
                    }
                    HStack {
                        histStat(ByteFormat.disk(cleanHistory.cleanedBytes), "Cleaned")
                        Spacer()
                        histStat("\(cleanHistory.uninstalled)", "Uninstalled")
                        Spacer()
                        histStat("\(cleanHistory.optimized)", "Optimized")
                    }
                }
                .padding(10)
                .background(cardBG)
            }

            HStack {
                Button(action: onOpen) {
                    Text("Open CleanMac")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: onQuit) {
                    Text("Quit")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }
    }

    private var privacyIcons: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(PrivacyStatus.cameraAllowed() ? Theme.ink.opacity(0.7) : Theme.muted.opacity(0.45))
                .help(PrivacyStatus.cameraAllowed() ? "Camera access allowed" : "Camera access off")
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PrivacyStatus.microphoneAllowed() ? PopDash.amber : Theme.muted.opacity(0.45))
                if PrivacyStatus.microphoneAllowed() {
                    Text("Mic OK")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(PopDash.amber)
                }
            }
            .help(PrivacyStatus.microphoneAllowed() ? "Microphone access allowed" : "Microphone access off")
        }
    }

    private func footerBtn(_ title: String, _ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private func histStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.ink)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.muted)
        }
    }

    private var cardBG: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.line.opacity(0.55), lineWidth: 1)
            )
    }

    // MARK: Helpers

    private func effectiveMem(_ m: StatusSnapshot) -> UInt64 {
        m.memTotal > 0 ? m.memTotal : ProcessInfo.processInfo.physicalMemory
    }
    private func memRatio(_ m: StatusSnapshot) -> Double {
        let t = Double(effectiveMem(m))
        guard t > 0 else { return 0 }
        return min(Double(m.memUsed) / t, 1)
    }
    private func diskRatio(_ m: StatusSnapshot) -> Double {
        guard m.diskTotal > 0 else { return 0 }
        return min(Double(m.diskUsed) / Double(m.diskTotal), 1)
    }
    private func pct(_ v: Double) -> String { "\(Int(v.rounded())) %" }
    private func rate(_ kbs: Double) -> String {
        if kbs >= 1024 { return String(format: "%.1f MB/s", kbs / 1024) }
        if kbs >= 1 { return String(format: "%.0f KB/s", kbs) }
        return "0 KB/s"
    }
    private func rateShort(_ kbs: Double) -> String {
        if kbs >= 1024 { return String(format: "%.1fM", kbs / 1024) }
        if kbs >= 1 { return String(format: "%.0fK", kbs) }
        return "0K"
    }
    private func loadText(_ m: StatusSnapshot) -> String {
        guard let a = m.loadAvg, a.count >= 1 else { return "—" }
        return String(format: "%.1f", a[0])
    }
    private func estTemp(_ pct: Double) -> String {
        "\(40 + Int((pct / 100) * 35))°C"
    }
    private func shortChip(_ m: StatusSnapshot) -> String {
        let c = m.chip ?? ""
        for gen in ["M4", "M3", "M2", "M1"] where c.localizedCaseInsensitiveContains(gen) {
            return gen
        }
        return c.split(separator: " ").first.map(String.init) ?? "Mac"
    }
    private func gpuFooter(_ m: StatusSnapshot, gpu: Double) -> String {
        let state = gpu < 8 ? "idle" : (gpu > 70 ? "busy" : "active")
        if let cores = m.gpuCores, cores > 0 {
            return "\(state) · \(cores) cores"
        }
        return "\(state) · \(m.numCPU) cores"
    }
    private func uptimeLine(_ m: StatusSnapshot) -> String {
        guard let sec = m.uptimeSec, sec > 0 else { return "up —" }
        let days = sec / 86_400
        let hours = (sec % 86_400) / 3600
        if days > 0 { return "up \(days) day\(days == 1 ? "" : "s")" }
        let mins = (sec % 3600) / 60
        if hours > 0 { return "up \(hours)h \(mins)m" }
        return "up \(mins)m"
    }
    private func memLabel(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024) }
        return String(format: "%.0f MB", mb)
    }
}
