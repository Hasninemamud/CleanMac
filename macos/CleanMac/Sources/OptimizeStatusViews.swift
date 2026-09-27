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

struct StatusView: View {
    @Environment(AppState.self) private var state
    @State private var historyLoad: [Double] = []
    @State private var historyMem: [Double] = []
    @State private var historyDisk: [Double] = []
    @State private var live = true

    var body: some View {
        Group {
            if let m = state.metrics {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(m.hostname)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Toggle(isOn: $live) {
                                Text("Live")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.muted)
                            }
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .tint(Theme.accent)
                        }

                        HStack(spacing: 12) {
                            RingMeter(
                                progress: loadRatio(m),
                                label: "Load",
                                detail: loadDetail(m),
                                color: meterColor(loadRatio(m))
                            )
                            RingMeter(
                                progress: memRatio(m),
                                label: "Memory",
                                detail: "\(ByteFormat.string(Int64(m.memUsed))) of \(ByteFormat.string(Int64(effectiveMemTotal(m))))",
                                color: meterColor(memRatio(m))
                            )
                            RingMeter(
                                progress: diskRatio(m),
                                label: "Disk",
                                detail: "\(ByteFormat.disk(m.diskFree)) free",
                                color: meterColor(diskRatio(m))
                            )
                        }

                        BarMeter(
                            title: "Memory pressure",
                            progress: memRatio(m),
                            leading: ByteFormat.string(Int64(m.memUsed)) + " used",
                            trailing: ByteFormat.string(Int64(effectiveMemTotal(m))) + " total",
                            color: meterColor(memRatio(m))
                        )
                        BarMeter(
                            title: "Disk usage",
                            progress: diskRatio(m),
                            leading: ByteFormat.disk(m.diskUsed) + " used",
                            trailing: ByteFormat.disk(m.diskTotal) + " total",
                            color: meterColor(diskRatio(m))
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Load history")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.ink)
                            Sparkline(values: historyLoad.isEmpty ? [loadRatio(m)] : historyLoad, color: Theme.accent)
                            HStack {
                                miniStat("CPU cores", "\(m.numCPU)")
                                miniStat("Uptime", formatUptime(m.uptimeSec ?? 0))
                                miniStat("Samples", "\(historyLoad.count)")
                            }
                        }
                        .padding(14)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.line, lineWidth: 1)
                        )
                    }
                }
            } else {
                EmptyState(
                    title: "Status",
                    systemImage: "gauge.with.dots.needle.33percent",
                    message: "Refresh for a live snapshot."
                )
            }
        }
        .onAppear {
            Task { await refresh() }
        }
        .task(id: live) {
            guard live else { return }
            while !Task.isCancelled && live && state.section == .status {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await refresh()
            }
        }
        .onChange(of: state.metrics?.timestamp) { _, _ in
            pushHistory()
        }
    }

    private func refresh() async {
        await state.scan()
        pushHistory()
    }

    private func pushHistory() {
        guard let m = state.metrics else { return }
        historyLoad.append(loadRatio(m))
        historyMem.append(memRatio(m))
        historyDisk.append(diskRatio(m))
        if historyLoad.count > 40 { historyLoad.removeFirst(historyLoad.count - 40) }
        if historyMem.count > 40 { historyMem.removeFirst(historyMem.count - 40) }
        if historyDisk.count > 40 { historyDisk.removeFirst(historyDisk.count - 40) }
    }

    private func effectiveMemTotal(_ m: StatusSnapshot) -> UInt64 {
        if m.memTotal > 0 { return m.memTotal }
        let physical = ProcessInfo.processInfo.physicalMemory
        if physical > 0 { return physical }
        return max(m.memUsed + m.memFree, 1)
    }

    private func memRatio(_ m: StatusSnapshot) -> Double {
        let total = Double(effectiveMemTotal(m))
        guard total > 0 else { return 0 }
        return min(Double(m.memUsed) / total, 1)
    }

    private func diskRatio(_ m: StatusSnapshot) -> Double {
        guard m.diskTotal > 0 else { return 0 }
        return min(Double(m.diskUsed) / Double(m.diskTotal), 1)
    }

    private func loadRatio(_ m: StatusSnapshot) -> Double {
        let load = m.loadAvg?.first ?? 0
        let cores = max(Double(m.numCPU), 1)
        return min(load / cores, 1)
    }

    private func loadDetail(_ m: StatusSnapshot) -> String {
        guard let a = m.loadAvg, a.count >= 3 else { return "—" }
        return String(format: "%.2f  %.2f  %.2f", a[0], a[1], a[2])
    }

    private func meterColor(_ p: Double) -> Color {
        if p >= 0.85 { return Theme.danger }
        if p >= 0.65 { return Theme.warn }
        return Theme.ok
    }

    private func miniStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.muted)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatUptime(_ sec: Int64) -> String {
        guard sec > 0 else { return "—" }
        let d = sec / 86400
        let h = (sec % 86400) / 3600
        let m = (sec % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        return "\(h)h \(m)m"
    }
}
