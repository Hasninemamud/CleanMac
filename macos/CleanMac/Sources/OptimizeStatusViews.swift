import SwiftUI

struct OptimizeView: View {
    @Environment(AppState.self) private var state
    @State private var complete = false
    @State private var appeared = false
    @State private var floatUp = false
    @State private var pulse = false
    @State private var showCheck = false

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
                            colors: [
                                Color.white.opacity(pulse ? 0.12 : 0.06),
                                Theme.Mole.bg.opacity(0),
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(pulse ? 1.08 : 1)

                Image(systemName: complete ? "moon.stars.fill" : "moon.fill")
                    .font(.system(size: 140, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Theme.Mole.ink.opacity(complete ? 0.95 : 0.8),
                                Theme.Mole.muted.opacity(0.55),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
                    .offset(y: floatUp ? -8 : 6)
                    .rotationEffect(.degrees(state.busy ? 8 : 0))
                    .scaleEffect(appeared ? 1 : 0.88)
                    .opacity(appeared ? 1 : 0)

                if showCheck {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(Theme.Mole.link)
                        .offset(x: 70, y: 70)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, 28)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: floatUp)
            .animation(
                state.busy
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.35),
                value: pulse
            )

            Text(headline)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Theme.Mole.ink)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: headline)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Text(state.busy ? "Working…" : subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Mole.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 40)
                .animation(.easeOut(duration: 0.25), value: state.busy)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 28)

            Button {
                Task { await primaryAction() }
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Mole.ctaInk.opacity(state.busy ? 0.4 : 0.9))
                    .frame(minWidth: 220)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(complete ? Theme.Mole.link.opacity(0.25) : Theme.Mole.cta)
                    .overlay(
                        Capsule().stroke(complete ? Theme.Mole.link.opacity(0.5) : Theme.Mole.line, lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .animation(.easeOut(duration: 0.25), value: complete)
            }
            .buttonStyle(PressableCapsuleStyle())
            .disabled(state.busy)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) { appeared = true }
            floatUp = true
            if state.optimizeActions.isEmpty {
                await state.scan()
            }
        }
        .onChange(of: state.busy) { _, busy in
            pulse = busy
        }
        .onChange(of: complete) { _, done in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showCheck = done
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { complete = false }
            await state.scan()
            return
        }
        if runnableIDs.isEmpty {
            await state.scan()
            return
        }
        await state.runOptimize(ids: runnableIDs, dryRun: false)
        if state.errorMessage == nil {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { complete = true }
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

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    /// Fixed trailing widths so header + rows share one grid.
    private enum ProcCol {
        static let mem: CGFloat = 70
        static let cpu: CGFloat = 88
        static let pwr: CGFloat = 40
        static let pid: CGFloat = 56
        static let action: CGFloat = 24
    }

    var body: some View {
        Group {
            if let m = state.metrics {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        LazyVGrid(columns: cols, spacing: 12) {
                            healthCard(m)
                            statusMiniCard(
                                title: "CPU", tint: Dash.green, badge: estTemp(m.cpuPercent),
                                primary: pct(m.cpuPercent ?? 0),
                                footer: "Load \(loadText(m)) · \(m.numCPU) cores",
                                history: historyCPU, chart: .bars
                            )
                            statusMiniCard(
                                title: "GPU", tint: Dash.amber, badge: estTemp(m.gpuPercent),
                                primary: pct(m.gpuPercent ?? 0),
                                footer: "\(m.numCPU) GPU cores",
                                history: historyGPU, chart: .line
                            )
                            statusMiniCard(
                                title: "MEMORY", tint: Theme.accent,
                                badge: "Pressure \(Int(((m.memPressure ?? memRatio(m)) * 100).rounded()))%",
                                primary: pct(memRatio(m) * 100),
                                footer: "\(ByteFormat.string(Int64(m.memUsed))) · \(ByteFormat.string(Int64(m.swapUsed ?? 0))) swap",
                                history: historyMem, chart: .bar
                            )
                            batteryCard(m)
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
                                footer: "↑ \(rate(m.netUpKBs ?? 0)) · ↓ \(rate(m.netDownKBs ?? 0))",
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
        let tint = score >= 80 ? Dash.green : Dash.amber
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("HEALTH")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(tint)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(tint)
                        .lineLimit(1)
                    Text(score >= 80 ? "All checks passed" : "Needs attention")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tint.opacity(0.45), Theme.surface.opacity(0)],
                                center: .center, startRadius: 2, endRadius: 36
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: score >= 80 ? "checkmark.seal.fill" : "sun.max.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(tint)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Text(healthMeta(m))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 158, maxHeight: 158, alignment: .topLeading)
        .clipped()
        .background(cardBG)
    }

    private func batteryCard(_ m: StatusSnapshot) -> some View {
        let pctVal = Double(m.batteryPct ?? 0) / 100
        let desktop = m.batteryState == "Desktop"
            || ((m.batteryPct ?? 0) == 0 && (m.batteryState == "Unknown" || m.batteryState == nil))
        let ring = desktop ? 1.0 : pctVal
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "battery.100.bolt")
                        .font(.system(size: 10, weight: .bold))
                    Text("BATTERY")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Dash.green)
                Spacer()
                Text(desktop ? "AC" : (m.batteryState ?? "—"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    if desktop {
                        Text("AC Power")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Desktop · no battery")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                    } else {
                        Text("\(m.batteryPct ?? 0)%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.ink)
                            .lineLimit(1)
                        Text(battDetail(m))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle().stroke(Theme.surface2, lineWidth: 6).frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: ring)
                        .stroke(Dash.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.ink)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Text(topDrainLine(m))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 158, maxHeight: 158, alignment: .topLeading)
        .clipped()
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
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tint)
                Spacer(minLength: 4)
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }

            if let secondary {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primary)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(secondary)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(tint)
                        .lineLimit(1)
                }
                .frame(minHeight: 44, alignment: .topLeading)
            } else {
                Text(primary)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minHeight: 44, alignment: .topLeading)
            }

            Group {
                switch chart {
                case .bars:
                    BarChart(values: history.isEmpty ? [0.1, 0.2, 0.15, 0.3] : history, color: tint)
                case .line:
                    Sparkline(values: history.isEmpty ? [0.2, 0.25, 0.22, 0.3, 0.28] : history, color: tint)
                        .padding(.vertical, 4)
                case .bar:
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surface2)
                            Capsule()
                                .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, geo.size.width * CGFloat(history.last ?? 0.3)))
                        }
                    }
                }
            }
            .frame(height: chart == .bar ? 8 : 28)
            .frame(maxHeight: .infinity, alignment: .center)

            Text(footer)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.middle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 158, maxHeight: 158, alignment: .topLeading)
        .clipped()
        .background(cardBG)
    }

    private func processTable(_ m: StatusSnapshot) -> some View {
        let procs = Array((m.processes ?? []).prefix(10))
        let maxCPU = max(procs.map(\.cpu).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 0) {
            processRow(
                name: "NAME (\(procs.count))",
                mem: "MEM",
                cpu: "% CPU",
                pwr: "PWR",
                pid: "PID",
                isHeader: true
            )
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.line).frame(height: 1)
            }

            ForEach(Array(procs.enumerated()), id: \.element.id) { idx, p in
                processRow(
                    name: p.name,
                    mem: String(format: "%.0f MB", p.memMB),
                    cpu: String(format: "%.0f", p.cpu),
                    pwr: String(format: "%.0f", min(p.cpu * 0.8, 99)),
                    pid: "\(p.pid)",
                    isHeader: false,
                    cpuBar: min(p.cpu / maxCPU, 1),
                    hot: p.cpu > 40,
                    selected: selectedPID == p.pid,
                    onQuit: { state.quitProcess(pid: p.pid) }
                )
                .padding(.vertical, 8)
                .background(selectedPID == p.pid ? Theme.accentSoft : (idx % 2 == 0 ? Color.clear : Theme.surface2.opacity(0.35)))
                .contentShape(Rectangle())
                .onTapGesture { selectedPID = p.pid }
                .contextMenu {
                    Button("Quit", role: .destructive) { state.quitProcess(pid: p.pid) }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(cardBG)
    }

    private func processRow(
        name: String,
        mem: String,
        cpu: String,
        pwr: String,
        pid: String,
        isHeader: Bool,
        cpuBar: Double = 0,
        hot: Bool = false,
        selected: Bool = false,
        onQuit: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(selected ? Dash.amber : Color.clear)
                    .frame(width: 3, height: 16)
                if isHeader {
                    Color.clear.frame(width: 14, height: 14)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.muted)
                        .frame(width: 14, height: 14)
                }
                Text(name)
                    .font(isHeader ? .system(size: 10, weight: .bold) : .system(size: 12, weight: .semibold))
                    .foregroundColor(isHeader ? Theme.muted : Theme.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(mem)
                .font(.system(size: isHeader ? 10 : 11, weight: isHeader ? .bold : .medium, design: .rounded))
                .foregroundColor(Theme.muted)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: ProcCol.mem, alignment: .trailing)

            Group {
                if isHeader {
                    Text(cpu)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    HStack(spacing: 6) {
                        Text(cpu)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.muted)
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                        Capsule()
                            .fill(Theme.surface2)
                            .frame(width: 44, height: 5)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(hot ? Dash.amber : Theme.muted.opacity(0.45))
                                    .frame(width: max(2, 44 * cpuBar), height: 5)
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(width: ProcCol.cpu, alignment: .trailing)

            Text(pwr)
                .font(.system(size: isHeader ? 10 : 11, weight: isHeader ? .bold : .medium, design: .rounded))
                .foregroundColor(hot ? Dash.amber : Theme.muted)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: ProcCol.pwr, alignment: .trailing)

            Text(pid)
                .font(.system(size: isHeader ? 10 : 11, weight: isHeader ? .bold : .medium, design: .rounded))
                .foregroundColor(Theme.muted)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: ProcCol.pid, alignment: .trailing)

            Group {
                if isHeader {
                    Color.clear.frame(width: ProcCol.action, height: 18)
                } else {
                    Menu {
                        Button("Quit", role: .destructive) { onQuit?() }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.muted)
                            .frame(width: ProcCol.action, height: 18)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: ProcCol.action, height: 18)
                    .clipped()
                }
            }
            .frame(width: ProcCol.action, alignment: .center)
            .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    private func healthMeta(_ m: StatusSnapshot) -> String {
        let gb = Int(Double(effectiveMem(m)) / 1_073_741_824)
        var parts = [shortChip(m)]
        if gb > 0 { parts.append("\(gb) GB") }
        parts.append(uptimeLine(m))
        return parts.joined(separator: " · ")
    }
    private func topDrainLine(_ m: StatusSnapshot) -> String {
        guard let top = (m.processes ?? []).first else { return "No process data" }
        return "Top drain \(top.name) · \(String(format: "%.1f", top.cpu))"
    }
    private func uptimeLine(_ m: StatusSnapshot) -> String {
        guard let sec = m.uptimeSec, sec > 0 else { return "up —" }
        let days = sec / 86_400
        let hours = (sec % 86_400) / 3600
        if days > 0 { return "up \(days)d \(hours)h" }
        let mins = (sec % 3600) / 60
        if hours > 0 { return "up \(hours)h \(mins)m" }
        return "up \(mins)m"
    }
    private func battDetail(_ m: StatusSnapshot) -> String {
        var parts: [String] = []
        if let c = m.batteryCycles, c > 0 { parts.append("\(c) cyc") }
        if let w = m.batteryWatts, w > 0 { parts.append(String(format: "%.0fW", w)) }
        if let s = m.batteryState, !s.isEmpty { parts.append(s) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
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
