import SwiftUI

struct OptimizeView: View {
    @Environment(AppState.self) private var state
    @State private var picked = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Maintenance actions run only after you confirm. Admin actions stay skipped in-app.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if state.optimizeActions.isEmpty {
                EmptyState(
                    title: "Optimize",
                    systemImage: "wrench.and.screwdriver",
                    message: "Preview to list safe maintenance steps."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(state.optimizeActions) { a in
                            HStack(alignment: .top, spacing: 10) {
                                CheckMark(
                                    isOn: Binding(
                                        get: { picked.contains(a.id) },
                                        set: { on in
                                            if on { picked.insert(a.id) } else { picked.remove(a.id) }
                                        }
                                    ),
                                    disabled: a.needsSudo
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(a.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.ink)
                                    Text(a.explanation)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Theme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if a.needsSudo {
                                        Text("Needs admin (Terminal)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Theme.accent)
                                    }
                                    Text(a.status + (a.detail.map { " · \($0)" } ?? ""))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Theme.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            Divider().background(Theme.line)
                        }
                    }
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.line, lineWidth: 1)
                    )
                }
            }

            HStack(spacing: 10) {
                Button("Preview") {
                    Task { await state.runOptimize(ids: [], dryRun: true) }
                }
                .buttonStyle(SoftButtonStyle())
                Button("Run selected") {
                    Task { await state.runOptimize(ids: Array(picked), dryRun: false) }
                }
                .buttonStyle(PrimaryButtonStyle(disabled: picked.isEmpty || state.busy))
                .disabled(picked.isEmpty || state.busy)
                Spacer()
            }
        }
        .onAppear {
            if state.optimizeActions.isEmpty {
                Task { await state.scan() }
            }
            picked = Set(state.optimizeActions.filter { !$0.needsSudo }.map(\.id))
        }
        .onChange(of: state.optimizeActions.map(\.id)) { _, _ in
            if picked.isEmpty {
                picked = Set(state.optimizeActions.filter { !$0.needsSudo }.map(\.id))
            }
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
    @State private var tab: StatusTab = .overview
    @State private var historyCPU: [Double] = []
    @State private var historyGPU: [Double] = []
    @State private var historyMem: [Double] = []
    @State private var historyDisk: [Double] = []
    @State private var historyNet: [Double] = []
    @State private var historyBatt: [Double] = []
    @State private var live = true

    private let triple = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    enum StatusTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case cpu = "CPU"
        case memory = "Memory"
        case disk = "Disk"
        case network = "Network"
        case gpu = "GPU"
        case battery = "Battery"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .cpu: return "cpu"
            case .memory: return "memorychip"
            case .disk: return "internaldrive"
            case .network: return "network"
            case .gpu: return "square.3.layers.3d"
            case .battery: return "battery.100"
            }
        }
    }

    var body: some View {
        Group {
            if let m = state.metrics {
                VStack(spacing: 12) {
                    tabBar
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            switch tab {
                            case .overview: overviewGrid(m)
                            case .cpu: focusPanel(title: "CPU", value: pct(m.cpuPercent ?? 0), color: Dash.blue, history: historyCPU, detail: "\(m.numCPU) cores · load \(loadText(m))")
                            case .memory: focusPanel(title: "Memory", value: ByteFormat.string(Int64(m.memUsed)), color: Dash.purple, history: historyMem, detail: "\(Int((memRatio(m)*100).rounded()))% · pressure \(Int(((m.memPressure ?? 0)*100).rounded()))%")
                            case .disk: focusPanel(title: "Disk", value: ByteFormat.disk(m.diskUsed), color: Dash.amber, history: historyDisk, detail: "\(ByteFormat.disk(m.diskFree)) free of \(ByteFormat.disk(m.diskTotal))")
                            case .network: focusPanel(title: "Network", value: rate((m.netDownKBs ?? 0) + (m.netUpKBs ?? 0)), color: Dash.teal, history: historyNet, detail: "↓ \(rate(m.netDownKBs ?? 0))  ↑ \(rate(m.netUpKBs ?? 0))")
                            case .gpu: focusPanel(title: "GPU", value: pct(m.gpuPercent ?? 0), color: Dash.pink, history: historyGPU, detail: "Estimated from display services")
                            case .battery: focusPanel(title: "Battery", value: battTitle(m), color: Dash.green, history: historyBatt, detail: m.batteryState ?? "—")
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            } else {
                EmptyState(title: "Status", systemImage: "gauge.with.dots.needle.33percent", message: "Refresh for a live snapshot.")
            }
        }
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

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(StatusTab.allCases) { t in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { tab = t }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: t.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(t.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(tab == t ? Theme.ink : Theme.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(tab == t ? Theme.surface2 : Color.clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                Toggle(isOn: $live) {
                    Text(live ? "Live" : "Paused")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.accent)
            }
            .padding(3)
            .background(Color.black.opacity(0.22))
            .clipShape(Capsule())
        }
    }

    private func overviewGrid(_ m: StatusSnapshot) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: triple, spacing: 12) {
                metricCard(
                    title: "CPU", icon: "cpu", tint: Dash.blue,
                    primary: pct(m.cpuPercent ?? 0),
                    rows: [("User", approxUser(m)), ("System", approxSystem(m))],
                    history: historyCPU
                )
                metricCard(
                    title: "Memory", icon: "memorychip", tint: Dash.purple,
                    primary: ByteFormat.string(Int64(m.memUsed)),
                    badge: pressureBadge(m),
                    rows: [("Used", "\(Int((memRatio(m)*100).rounded()))%"), ("Swap", ByteFormat.string(Int64(m.swapUsed ?? 0)))],
                    history: historyMem
                )
                metricCard(
                    title: "GPU", icon: "square.3.layers.3d", tint: Dash.pink,
                    primary: pct(m.gpuPercent ?? 0),
                    rows: [("Render", pct(m.gpuPercent ?? 0)), ("Est.", "services")],
                    history: historyGPU
                )
                metricCard(
                    title: "Disk", icon: "internaldrive", tint: Dash.amber,
                    primary: ByteFormat.disk(m.diskUsed),
                    rows: [("Free", ByteFormat.disk(m.diskFree)), ("Total", ByteFormat.disk(m.diskTotal))],
                    history: historyDisk
                )
                metricCard(
                    title: "Network", icon: "network", tint: Dash.teal,
                    primary: rate((m.netDownKBs ?? 0) + (m.netUpKBs ?? 0)),
                    rows: [("Down", rate(m.netDownKBs ?? 0)), ("Up", rate(m.netUpKBs ?? 0))],
                    history: historyNet
                )
                metricCard(
                    title: "Battery", icon: "battery.100", tint: Dash.green,
                    primary: battTitle(m),
                    rows: [("State", m.batteryState ?? "—"), ("Health", m.healthLabel ?? "—")],
                    history: historyBatt
                )
            }

            LazyVGrid(columns: triple, spacing: 12) {
                donutCard(
                    title: "Memory by Type",
                    center: "\(Int((memRatio(m)*100).rounded()))%\nin use",
                    slices: memTypeSlices(m)
                )
                donutCard(
                    title: "Memory by App",
                    center: ByteFormat.string(Int64((m.processes ?? []).prefix(5).reduce(0) { $0 + $1.memMB } * 1024 * 1024)),
                    slices: appMemSlices(m)
                )
                donutCard(
                    title: "CPU by App",
                    center: String(format: "%.0f%%\ntop", (m.processes ?? []).prefix(5).reduce(0) { $0 + $1.cpu }),
                    slices: appCPUSlices(m)
                )
            }
        }
    }

    private func focusPanel(title: String, value: String, color: Color, history: [Double], detail: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.muted)
                Spacer()
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
            }
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.muted)
            BarChart(values: history.isEmpty ? [0.2] : history, color: color)
                .frame(height: 120)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    // MARK: Cards

    private func metricCard(
        title: String,
        icon: String,
        tint: Color,
        primary: String,
        badge: String? = nil,
        rows: [(String, String)],
        history: [Double]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(tint.opacity(0.2))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(tint)
                        )
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.ink)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted.opacity(0.7))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(primary)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Dash.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Dash.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(rows, id: \.0) { row in
                    HStack(spacing: 6) {
                        Circle().fill(tint).frame(width: 5, height: 5)
                        Text("\(row.0): \(row.1)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                    }
                }
            }

            BarChart(values: history.isEmpty ? [0.15, 0.2, 0.18] : history, color: tint)
                .frame(height: 36)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                switch title {
                case "CPU": tab = .cpu
                case "Memory": tab = .memory
                case "GPU": tab = .gpu
                case "Disk": tab = .disk
                case "Network": tab = .network
                case "Battery": tab = .battery
                default: break
                }
            }
        }
    }

    private func donutCard(title: String, center: String, slices: [(String, Double, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.ink)
            HStack(spacing: 12) {
                DonutChart(slices: slices.map { ($0.1, $0.2) }, center: center)
                    .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(slices.prefix(4), id: \.0) { s in
                        HStack(spacing: 6) {
                            Circle().fill(s.2).frame(width: 7, height: 7)
                            Text(s.0)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.muted)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    // MARK: Data helpers

    private func memTypeSlices(_ m: StatusSnapshot) -> [(String, Double, Color)] {
        let total = max(Double(effectiveMem(m)), 1)
        let app = Double(m.memApp ?? 0)
        let wired = Double(m.memWired ?? 0)
        let comp = Double(m.memCompressed ?? 0)
        let cached = Double(m.memCached ?? 0)
        let free = max(total - app - wired - comp - cached, 0)
        return [
            ("App", app / total, Dash.purple),
            ("Wired", wired / total, Dash.blue),
            ("Compressed", comp / total, Dash.pink),
            ("Cached", cached / total, Dash.amber),
            ("Free", free / total, Theme.muted.opacity(0.5)),
        ].filter { $0.1 > 0.01 }
    }

    private func appMemSlices(_ m: StatusSnapshot) -> [(String, Double, Color)] {
        let colors = [Dash.purple, Dash.blue, Dash.pink, Dash.teal, Dash.amber, Theme.muted]
        let procs = Array((m.processes ?? []).sorted { $0.memMB > $1.memMB }.prefix(5))
        let sum = max(procs.reduce(0) { $0 + $1.memMB }, 1)
        return procs.enumerated().map { i, p in
            (p.name, p.memMB / sum, colors[i % colors.count])
        }
    }

    private func appCPUSlices(_ m: StatusSnapshot) -> [(String, Double, Color)] {
        let colors = [Dash.blue, Dash.teal, Dash.amber, Dash.pink, Dash.purple, Theme.muted]
        let procs = Array((m.processes ?? []).prefix(5))
        let sum = max(procs.reduce(0) { $0 + $1.cpu }, 1)
        return procs.enumerated().map { i, p in
            (p.name, p.cpu / sum, colors[i % colors.count])
        }
    }

    private func pressureBadge(_ m: StatusSnapshot) -> String {
        let p = m.memPressure ?? memRatio(m)
        if p < 0.65 { return "✓ Normal" }
        if p < 0.85 { return "Warn" }
        return "Critical"
    }

    private func refresh() async {
        // quiet: don't flip busy / status chrome (avoids Status tab blink every 2s)
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
        for arr in [historyCPU, historyGPU, historyMem, historyDisk, historyNet, historyBatt] as [[Double]] { _ = arr }
        trim(&historyCPU); trim(&historyGPU); trim(&historyMem)
        trim(&historyDisk); trim(&historyNet); trim(&historyBatt)
    }

    private func trim(_ a: inout [Double]) {
        if a.count > 28 { a.removeFirst(a.count - 28) }
    }

    private func effectiveMem(_ m: StatusSnapshot) -> UInt64 {
        if m.memTotal > 0 { return m.memTotal }
        return ProcessInfo.processInfo.physicalMemory
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
        if kbs >= 1 { return String(format: "%.0f kB/s", kbs) }
        return "0 kB/s"
    }
    private func battTitle(_ m: StatusSnapshot) -> String {
        if (m.batteryState == "Desktop") || ((m.batteryPct ?? 0) == 0 && (m.batteryState == "Unknown" || m.batteryState == nil)) {
            return "AC"
        }
        return "\(m.batteryPct ?? 0)%"
    }
    private func loadText(_ m: StatusSnapshot) -> String {
        guard let a = m.loadAvg, a.count >= 1 else { return "—" }
        return String(format: "%.2f", a[0])
    }
    private func approxUser(_ m: StatusSnapshot) -> String {
        pct((m.cpuPercent ?? 0) * 0.65)
    }
    private func approxSystem(_ m: StatusSnapshot) -> String {
        pct((m.cpuPercent ?? 0) * 0.35)
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
