import SwiftUI

struct OptimizeView: View {
    @Environment(AppState.self) private var state
    @State private var complete = false

    private var runnableIDs: [String] {
        state.optimizeActions.filter { !$0.needsSudo }.map(\.id)
    }

    private var subtitle: String {
        let titles = state.optimizeActions.map(\.title)
        if titles.isEmpty { return "Launch speed · System databases · System maintenance" }
        return titles.prefix(4).joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.ink.opacity(0.10), Theme.bg.opacity(0)],
                            center: .center,
                            startRadius: 30,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                Image(systemName: "moon.fill")
                    .font(.system(size: 140, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.ink.opacity(0.75), Theme.muted.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: Theme.ink.opacity(0.12), radius: 24, y: 10)
            }
            .padding(.bottom, 28)

            Text(headline)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)

            Text(state.busy ? "Working…" : subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 40)

            Spacer(minLength: 28)

            Button {
                Task { await primaryAction() }
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.ink.opacity(state.busy ? 0.4 : 0.85))
                    .frame(minWidth: 220)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(Theme.surface2)
                    .overlay(
                        Capsule().stroke(Theme.line, lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(state.busy)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if state.optimizeActions.isEmpty {
                await state.scan()
            }
        }
    }

    private var headline: String {
        if state.busy { return "Running maintenance…" }
        if complete { return "Maintenance complete" }
        return "Ready to maintain"
    }

    private var buttonTitle: String {
        if complete { return "Rest, CleanMac" }
        if runnableIDs.isEmpty { return "Refresh catalog" }
        return "Run maintenance"
    }

    private func primaryAction() async {
        if complete {
            complete = false
            await state.scan()
            return
        }
        if runnableIDs.isEmpty {
            await state.scan()
            return
        }
        await state.runOptimize(ids: runnableIDs, dryRun: false)
        if state.errorMessage == nil {
            complete = true
        }
    }
}

// MARK: - Status (Overview dashboard)

private enum Dash {
    static let blue = Color(red: 0.27, green: 0.53, blue: 0.99)
    static let purple = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let pink = Color(red: 0.93, green: 0.28, blue: 0.60)
    static let amber = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let teal = Color(red: 0.08, green: 0.72, blue: 0.65)
    static let green = Color(red: 0.13, green: 0.77, blue: 0.37)
}

struct StatusView: View {
    @Environment(AppState.self) private var state
    @State private var historyCPU: [Double] = []
    @State private var historyGPU: [Double] = []
    @State private var historyMem: [Double] = []
    @State private var historyDisk: [Double] = []
    @State private var historyNet: [Double] = []
    @State private var historyBatt: [Double] = []
    @State private var selectedPID: Int?
    @State private var live = true

    var body: some View {
        Group {
            if let m = state.metrics {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            healthCard(m)
                                .frame(maxWidth: .infinity)
                            statusMiniCard(
                                title: "CPU", tint: Dash.green, badge: estTemp(m.cpuPercent),
                                primary: pct(m.cpuPercent ?? 0),
                                footer: "idle · Load \(loadText(m)) / \(m.numCPU) cores",
                                history: historyCPU, chart: .bars
                            )
                            statusMiniCard(
                                title: "GPU", tint: Dash.amber, badge: estTemp(m.gpuPercent),
                                primary: pct(m.gpuPercent ?? 0),
                                footer: "idle · \(m.numCPU) GPU cores",
                                history: historyGPU, chart: .line
                            )
                            statusMiniCard(
                                title: "MEMORY", tint: Theme.accent,
                                badge: "Pressure \(Int(((m.memPressure ?? memRatio(m)) * 100).rounded()))%",
                                primary: pct(memRatio(m) * 100),
                                footer: "\(ByteFormat.string(Int64(m.memUsed))) · \(ByteFormat.string(Int64(m.swapUsed ?? 0))) swap",
                                history: historyMem, chart: .bar
                            )
                        }
                        .frame(minHeight: 168)

                        HStack(alignment: .top, spacing: 12) {
                            batteryCard(m)
                                .frame(maxWidth: .infinity)
                            statusMiniCard(
                                title: "DISK", tint: Dash.blue,
                                badge: ByteFormat.disk(m.diskTotal),
                                primary: ByteFormat.disk(m.diskFree),
                                footer: "\(ByteFormat.disk(m.diskUsed)) used · \(Int((diskRatio(m) * 100).rounded()))%",
                                history: historyDisk, chart: .bar
                            )
                            statusMiniCard(
                                title: "NETWORK", tint: Dash.teal, badge: "Wi-Fi",
                                primary: rate((m.netDownKBs ?? 0) + (m.netUpKBs ?? 0)),
                                footer: "↑ \(rate(m.netUpKBs ?? 0)) · Wi-Fi",
                                history: historyNet, chart: .line
                            )
                            statusMiniCard(
                                title: "THERMAL", tint: Dash.green,
                                badge: m.thermal ?? "Normal",
                                primary: "CPU \(estTemp(m.cpuPercent))",
                                secondary: "GPU \(estTemp(m.gpuPercent))",
                                footer: "\(shortChip(m)) · peak \(estTemp((m.cpuPercent ?? 0) * 1.4))",
                                history: [min((m.cpuPercent ?? 0) / 100, 1)], chart: .bar
                            )
                        }
                        .frame(minHeight: 168)

                        processTable(m)
                    }
                    .padding(.bottom, 8)
                }
            } else {
                EmptyState(title: "Status", systemImage: "gauge.with.dots.needle.33percent", message: "Refresh for a live snapshot.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { Task { await refresh() } }
        .task(id: live) {
            guard live else { return }
            while !Task.isCancelled && live && state.section == .status {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await refresh()
            }
        }
        .onChange(of: state.metrics?.timestamp) { _, _ in pushHistory() }
    }

    // MARK: Cards

    private func healthCard(_ m: StatusSnapshot) -> some View {
        let score = m.healthScore ?? 100
        let label = m.healthLabel ?? "Excellent"
        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("HEALTH", systemImage: "sun.max.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Dash.green)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(chipBadges(m), id: \.self) { b in
                            Text(b)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.muted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.surface2)
                                .clipShape(Capsule())
                        }
                    }
                }
                Text("\(score) \(label)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.ink)
                Text(score >= 80 ? "All checks passed" : "Needs attention")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.muted)
                Text(uptimeLine(m))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.muted)
            }
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Dash.amber.opacity(0.55), Theme.surface.opacity(0)],
                            center: .center, startRadius: 4, endRadius: 54
                        )
                    )
                    .frame(width: 100, height: 100)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Dash.amber)
            }
        }
        .padding(16)
        .background(cardBG)
    }

    private func batteryCard(_ m: StatusSnapshot) -> some View {
        let pctVal = Double(m.batteryPct ?? 0) / 100
        let desktop = m.batteryState == "Desktop" || ((m.batteryPct ?? 0) == 0 && (m.batteryState == "Unknown" || m.batteryState == nil))
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("BATTERY", systemImage: "battery.100.bolt")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Dash.green)
                    Spacer()
                    Text(m.healthLabel.map { "\($0)" } ?? "—")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
                if desktop {
                    Text("AC Power")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.ink)
                    Text("Desktop · no battery")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.muted)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(m.batteryPct ?? 0)% \(m.batteryState ?? "")")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.ink)
                        if let w = m.batteryWatts, w > 0 {
                            Text(String(format: "%.0fW", w))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Dash.amber)
                        }
                    }
                    Text(battDetail(m))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
                if let top = (m.processes ?? []).first {
                    Text("Top drain \(top.name) · \(String(format: "%.1f", top.cpu))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
            }
            ZStack {
                Circle().stroke(Theme.surface2, lineWidth: 8).frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: desktop ? 1 : pctVal)
                    .stroke(Dash.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Theme.ink)
            }
        }
        .padding(16)
        .background(cardBG)
    }

    private enum MiniChart { case bars, line, bar }

    private func statusMiniCard(
        title: String,
        tint: Color,
        badge: String,
        primary: String,
        secondary: String? = nil,
        footer: String,
        history: [Double],
        chart: MiniChart
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tint)
                Spacer()
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted)
            }
            if let secondary {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primary)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.ink)
                    Text(secondary)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(tint)
                }
            } else {
                Text(primary)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
            }
            Group {
                switch chart {
                case .bars:
                    BarChart(values: history.isEmpty ? [0.1, 0.2, 0.15, 0.3] : history, color: tint)
                case .line:
                    Sparkline(values: history.isEmpty ? [0.2, 0.25, 0.22, 0.3, 0.28] : history, color: tint)
                case .bar:
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surface2)
                            Capsule()
                                .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, geo.size.width * CGFloat(history.last ?? 0.3)))
                        }
                    }
                    .frame(height: 8)
                }
            }
            .frame(height: chart == .bar ? 8 : 36)
            Text(footer)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.muted)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBG)
    }

    private func processTable(_ m: StatusSnapshot) -> some View {
        let procs = Array((m.processes ?? []).prefix(10))
        let maxCPU = max(procs.map(\.cpu).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NAME (\(procs.count))").frame(maxWidth: .infinity, alignment: .leading)
                Text("MEM").frame(width: 70, alignment: .trailing)
                Text("% CPU").frame(width: 110, alignment: .leading)
                Text("PWR").frame(width: 48, alignment: .trailing)
                Text("PID").frame(width: 56, alignment: .trailing)
                Text("").frame(width: 28)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Theme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ForEach(procs) { p in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(selectedPID == p.pid ? Dash.amber : Color.clear)
                        .frame(width: 3, height: 22)
                    Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))
                        .resizable()
                        .frame(width: 18, height: 18)
                        .opacity(0.001) // placeholder spacing; real icon below
                        .overlay {
                            Image(systemName: "app.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.muted)
                        }
                    Text(p.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.0f MB", p.memMB))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.muted)
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                    HStack(spacing: 6) {
                        Text(String(format: "%.0f", p.cpu))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.muted)
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.surface2)
                                Capsule()
                                    .fill(p.cpu > 40 ? Dash.amber : Theme.muted.opacity(0.45))
                                    .frame(width: max(2, geo.size.width * CGFloat(p.cpu / maxCPU)))
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(width: 110, alignment: .leading)
                    Text(String(format: "%.0f", min(p.cpu * 0.8, 99)))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(p.cpu > 40 ? Dash.amber : Theme.muted)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    Text("\(p.pid)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.muted)
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                    Menu {
                        Button("Quit") { state.quitProcess(pid: p.pid) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.muted)
                            .frame(width: 28, height: 22)
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(selectedPID == p.pid ? Theme.accentSoft : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { selectedPID = p.pid }
            }
        }
        .padding(.vertical, 4)
        .background(cardBG)
    }

    private var cardBG: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }

    // MARK: Helpers

    private func refresh() async {
        await state.scan(quiet: true)
        pushHistory()
    }

    private func pushHistory() {
        guard let m = state.metrics else { return }
        historyCPU.append(min((m.cpuPercent ?? 0) / 100, 1))
        historyGPU.append(min((m.gpuPercent ?? 0) / 100, 1))
        historyMem.append(memRatio(m))
        historyDisk.append(diskRatio(m))
        historyNet.append(min(((m.netDownKBs ?? 0) + (m.netUpKBs ?? 0)) / 800, 1))
        historyBatt.append(Double(m.batteryPct ?? 0) / 100)
        trim(&historyCPU); trim(&historyGPU); trim(&historyMem)
        trim(&historyDisk); trim(&historyNet); trim(&historyBatt)
    }

    private func trim(_ a: inout [Double]) {
        if a.count > 28 { a.removeFirst(a.count - 28) }
    }

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

    private func pct(_ v: Double) -> String { "\(Int(v.rounded()))%" }
    private func rate(_ kbs: Double) -> String {
        if kbs >= 1024 { return String(format: "%.1f MB/s", kbs / 1024) }
        if kbs >= 1 { return String(format: "%.0f KB/s", kbs) }
        return "0 KB/s"
    }
    private func loadText(_ m: StatusSnapshot) -> String {
        guard let a = m.loadAvg, a.count >= 1 else { return "—" }
        return String(format: "%.1f", a[0])
    }
    private func estTemp(_ pct: Double?) -> String {
        let t = 40 + Int(((pct ?? 0) / 100) * 35)
        return "\(t)°C"
    }
    private func shortChip(_ m: StatusSnapshot) -> String {
        let c = m.chip ?? ""
        if c.localizedCaseInsensitiveContains("M4") { return "M4" }
        if c.localizedCaseInsensitiveContains("M3") { return "M3" }
        if c.localizedCaseInsensitiveContains("M2") { return "M2" }
        if c.localizedCaseInsensitiveContains("M1") { return "M1" }
        return c.split(separator: " ").first.map(String.init) ?? "Mac"
    }
    private func chipBadges(_ m: StatusSnapshot) -> [String] {
        var out = [shortChip(m)]
        let gb = Int(Double(effectiveMem(m)) / 1_073_741_824)
        if gb > 0 { out.append("\(gb) GB") }
        if let os = m.osVersion, !os.isEmpty { out.append(os.hasPrefix("macOS") ? os : "macOS \(os)") }
        return out
    }
    private func uptimeLine(_ m: StatusSnapshot) -> String {
        guard let sec = m.uptimeSec, sec > 0 else { return "up —" }
        let days = sec / 86_400
        let hours = (sec % 86_400) / 3600
        if days > 0 { return "up \(days) day\(days == 1 ? "" : "s") · \(hours)h" }
        let mins = (sec % 3600) / 60
        if hours > 0 { return "up \(hours)h \(mins)m" }
        return "up \(mins) minutes"
    }
    private func battDetail(_ m: StatusSnapshot) -> String {
        var parts: [String] = []
        if let c = m.batteryCycles, c > 0 { parts.append("\(c) cyc") }
        if let w = m.batteryWatts, w > 0 { parts.append(String(format: "%.0fW", w)) }
        parts.append(m.batteryState ?? "")
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

// MARK: - Charts

struct BarChart: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let n = max(values.count, 1)
            let gap: CGFloat = 2
            let w = max(2, (geo.size.width - gap * CGFloat(n - 1)) / CGFloat(n))
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color.opacity(0.85))
                        .frame(width: w, height: max(3, geo.size.height * min(max(v, 0), 1)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct DonutChart: View {
    let slices: [(Double, Color)]
    let center: String

    var body: some View {
        ZStack {
            ForEach(Array(sliceAngles().enumerated()), id: \.offset) { _, item in
                Circle()
                    .trim(from: item.start, to: item.end)
                    .stroke(item.color, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            Text(center)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
    }

    private func sliceAngles() -> [(start: CGFloat, end: CGFloat, color: Color)] {
        let total = max(slices.reduce(0) { $0 + $1.0 }, 0.001)
        var start: CGFloat = 0
        var out: [(CGFloat, CGFloat, Color)] = []
        for s in slices {
            let frac = CGFloat(s.0 / total)
            out.append((start, start + frac, s.1))
            start += frac
        }
        return out.map { (start: $0.0, end: $0.1, color: $0.2) }
    }
}

struct CapsuleBar: View {
    let progress: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule()
                    .fill(color)
                    .frame(width: max(4, geo.size.width * min(max(progress, 0), 1)))
            }
        }
    }
}

struct DualDiskBar: View {
    let used: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule()
                    .fill(Dash.blue)
                    .frame(width: max(4, geo.size.width * min(max(used, 0), 1)))
            }
        }
    }
}

struct SegmentBar: View {
    let progress: Double
    let color: Color
    private let segments = 24
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Double(i) / Double(segments) < progress ? color : Theme.line)
            }
        }
    }
}
