import SwiftUI

struct CleanView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 12) {
            segmentBar
            toolbar
            ItemTable(items: state.currentItems, selected: $state.selected)
        }
    }

    private var segmentBar: some View {
        HStack(spacing: 4) {
            ForEach(AppState.CleanSegment.allCases) { s in
                SegmentPill(title: s.rawValue, selected: state.cleanSegment == s) {
                    state.cleanSegment = s
                    state.selected.removeAll()
                }
            }
            Spacer()
        }
        .padding(3)
        .background(Color.black.opacity(0.22))
        .clipShape(Capsule())
        .frame(maxWidth: 360, alignment: .leading)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if state.cleanSegment == .junk {
                Button {
                    state.selectSafe()
                } label: {
                    Text("Select safe")
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(state.junk.isEmpty)
            }
            Spacer()
            Text("\(state.currentItems.count) items")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.muted)
        }
    }
}

struct AppsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    state.selected = Set(state.orphans.map(\.path))
                } label: {
                    Text("Select orphaned leftovers")
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(state.orphans.isEmpty)
                Spacer()
                Text("\(state.orphans.count) orphans · \(state.apps.count) apps")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.muted)
            }
            ItemTable(items: state.currentItems, selected: $state.selected)
        }
    }
}

struct AnalyzeView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(AppState.AnalyzeSegment.allCases) { s in
                    SegmentPill(title: s.rawValue, selected: state.analyzeSegment == s) {
                        state.analyzeSegment = s
                        state.selected.removeAll()
                    }
                }
                Spacer()
            }
            .padding(3)
            .background(Color.black.opacity(0.22))
            .clipShape(Capsule())
            .frame(maxWidth: 360, alignment: .leading)

            switch state.analyzeSegment {
            case .overview:
                OverviewPane(overview: state.overview)
            case .large:
                ItemTable(items: state.large, selected: $state.selected)
            case .dupes:
                DupesPane(groups: state.dupes, selected: $state.selected)
            }
        }
    }
}

struct OverviewPane: View {
    let overview: OverviewResponse?

    var body: some View {
        if let o = overview {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        metricCard("Used", ByteFormat.string(o.usedBytes))
                        metricCard("Free", ByteFormat.string(o.freeBytes))
                        metricCard("Total", ByteFormat.string(o.totalBytes))
                    }
                    VStack(spacing: 0) {
                        ForEach(["apps", "documents", "caches", "other"], id: \.self) { key in
                            HStack {
                                Text(key.capitalized)
                                    .foregroundColor(Theme.ink)
                                Spacer()
                                Text(ByteFormat.string(o.categoryBytes[key] ?? 0))
                                    .foregroundColor(Theme.muted)
                                    .monospacedDigit()
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            if key != "other" {
                                Divider().background(Theme.line)
                            }
                        }
                    }
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.line, lineWidth: 1)
                    )

                    Text("Top folders")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.muted)
                    VStack(spacing: 0) {
                        ForEach(o.topFolders) { f in
                            HStack {
                                Text(f.name).foregroundColor(Theme.ink)
                                Spacer()
                                Text(ByteFormat.string(f.byteSize))
                                    .foregroundColor(Theme.muted)
                                    .monospacedDigit()
                            }
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            Divider().background(Theme.line)
                        }
                    }
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        } else {
            EmptyState(
                title: "Disk map",
                systemImage: "internaldrive",
                message: "Scan to see volume usage and top folders."
            )
        }
    }

    private func metricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.muted)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Theme.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }
}

struct DupesPane: View {
    let groups: [DupeGroup]
    @Binding var selected: Set<String>

    var body: some View {
        if groups.isEmpty {
            EmptyState(title: "No duplicates", systemImage: "doc.on.doc", message: "Scan to find duplicate files.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(groups) { g in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(ByteFormat.string(g.byteSize)) · reclaim \(ByteFormat.string(g.reclaimableBytes))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.muted)
                            ForEach(g.files) { f in
                                ItemRow(item: f, selected: $selected)
                            }
                        }
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.line, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

struct ItemTable: View {
    let items: [ScanItem]
    @Binding var selected: Set<String>

    var body: some View {
        if items.isEmpty {
            EmptyState(title: "Nothing yet", systemImage: "tray", message: "Run a scan to populate this list.")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        ItemRow(item: item, selected: $selected)
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
    }
}

struct ItemRow: View {
    let item: ScanItem
    @Binding var selected: Set<String>
    @Environment(AppState.self) private var state

    private var isOn: Binding<Bool> {
        Binding(
            get: { selected.contains(item.path) },
            set: { on in
                if on { selected.insert(item.path) } else { selected.remove(item.path) }
            }
        )
    }

    private var blocked: Bool {
        item.safety == "blocked" || Safety.isBlocked(item.path)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            CheckMark(isOn: isOn, disabled: blocked)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                Text(item.path)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            SafetyBadge(safety: item.safety)

            Text(ByteFormat.string(item.byteSize))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.ink)
                .monospacedDigit()
                .frame(width: 68, alignment: .trailing)
                .fixedSize()

            Button("Reveal") { state.reveal(item.path) }
                .buttonStyle(SoftButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(selected.contains(item.path) ? Theme.accentSoft : Color.clear)
    }
}

struct EmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Theme.accent)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.ink)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(Theme.surface.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }
}
