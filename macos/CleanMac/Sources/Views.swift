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
        .background(Theme.surface2)
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

struct SoftwareView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(AppState.SoftwareSegment.allCases) { s in
                    SegmentPill(title: s.rawValue, selected: state.softwareSegment == s) {
                        state.softwareSegment = s
                        state.selected.removeAll()
                    }
                }
                Spacer()
            }
            .padding(3)
            .background(Theme.surface2)
            .clipShape(Capsule())

            HStack(spacing: 12) {
                if state.softwareSegment == .caches || state.softwareSegment == .leftovers {
                    Button { state.selected = Set(state.currentItems.map(\.path)) } label: { Text("Select all") }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(state.currentItems.isEmpty)
                } else if state.softwareSegment == .orphans {
                    Button { state.selected = Set(state.orphans.map(\.path)) } label: { Text("Select orphans") }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(state.orphans.isEmpty)
                } else if state.softwareSegment == .uninstall {
                    Button { state.selected = Set(state.apps.map(\.path)) } label: { Text("Select apps") }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(state.apps.isEmpty)
                }
                Spacer()
                Text(summary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.muted)
            }

            switch state.softwareSegment {
            case .updates:
                updatesList
            case .startup:
                startupList
            default:
                ItemTable(items: state.currentItems, selected: $state.selected)
            }
        }
    }

    private var summary: String {
        switch state.softwareSegment {
        case .caches: return "\(state.appCacheItems.count) cache items"
        case .leftovers: return "\(state.appLeftoverItems.count) leftovers"
        case .orphans: return "\(state.orphans.count) orphans"
        case .uninstall: return "\(state.apps.count) apps — select to Trash"
        case .updates: return "\(state.updates.count) update sources"
        case .startup: return "\(state.startupItems.count) startup items"
        }
    }

    private var updatesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(state.updates) { u in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(u.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.ink)
                            Text(u.detail ?? u.source).font(.system(size: 10)).foregroundColor(Theme.muted)
                        }
                        Spacer()
                        Text(u.source).font(.system(size: 10, weight: .bold)).foregroundColor(Theme.accent)
                        Button("Open") { state.openUpdate(u) }.buttonStyle(SoftButtonStyle())
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    Divider().background(Theme.line)
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var startupList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(state.startupItems) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.ink)
                            Text(s.path).font(.system(size: 10)).foregroundColor(Theme.muted).lineLimit(1)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { s.enabled },
                            set: { on in Task { await state.setStartup(path: s.path, enabled: on) } }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    Divider().background(Theme.line)
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct AppsView: View {
    var body: some View { SoftwareView() }
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
            .background(Theme.surface2)
            .clipShape(Capsule())
            .frame(maxWidth: 360, alignment: .leading)

            switch state.analyzeSegment {
            case .overview:
                OverviewPane(overview: state.overview)
            case .map:
                TreemapPane()
            case .large:
                ItemTable(items: state.large, selected: $state.selected)
            case .dupes:
                DupesPane(groups: state.dupes, selected: $state.selected)
            }
        }
    }
}

struct TreemapPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Home") {
                    state.treemapPath = NSHomeDirectory()
                    Task { await state.scan() }
                }
                .buttonStyle(SoftButtonStyle())
                Text(state.treemapPath)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            if let node = state.treemap {
                let total = max(node.byteSize, 1)
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(node.children ?? []) { child in
                            Button {
                                if child.isDirectory == true {
                                    state.treemapPath = child.path
                                    Task { await state.scan() }
                                } else {
                                    state.reveal(child.path)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Theme.accent.opacity(0.85))
                                            .frame(width: max(4, geo.size.width * CGFloat(child.byteSize) / CGFloat(total)))
                                    }
                                    .frame(height: 18)
                                    Text(child.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.ink)
                                        .frame(width: 140, alignment: .leading)
                                        .lineLimit(1)
                                    Text(ByteFormat.disk(child.byteSize))
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.muted)
                                        .frame(width: 72, alignment: .trailing)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                EmptyState(title: "Folder map", systemImage: "square.grid.3x3", message: "Scan a folder to drill into disk usage.")
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
                        metricCard("Used", ByteFormat.disk(o.usedBytes))
                        metricCard("Free", ByteFormat.disk(o.freeBytes))
                        metricCard("Total", ByteFormat.disk(o.totalBytes))
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
                Text(item.explanation ?? item.path)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            SafetyBadge(safety: item.safety)
            if item.isCacheLeftover {
                Text("CACHE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }

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
