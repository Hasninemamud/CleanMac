import SwiftUI

struct CleanView: View {
    @Environment(AppState.self) private var state
    @State private var expanded = Set<String>()
    @State private var heroReady = false

    var body: some View {
        @Bindable var state = state
        ZStack {
            switch state.cleanPhase {
            case .hero:
                hero
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .offset(y: 12)),
                        removal: .opacity.combined(with: .offset(y: -16))
                    ))
            case .review:
                review(selected: $state.selected)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .offset(y: 20))
                    ))
            }
            if state.showAIReview {
                AICleanupView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: state.cleanPhase)
        .pageEnter()
        .task {
            withAnimation(.easeOut(duration: 0.55)) { heroReady = true }
            if state.cleanItems.isEmpty, !state.busy {
                await state.scan()
            }
        }
    }

    // MARK: - Hero (scan summary)

    private var hero: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if state.showAICleanup && state.aiHasData {
                    Button {
                        state.showAIReview = true
                        Task { await state.scanAI() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("AI Cleanup")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Theme.Mole.ink.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.Mole.surface.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.Mole.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("AI Cleanup & Care")
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
            }
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Feature.clean.opacity(state.busy ? 0.28 : 0.14),
                                Theme.Feature.pageBG(for: .clean).opacity(0),
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(state.busy ? 1.05 : 1)
                    .animation(
                        state.busy
                            ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                            : .spring(response: 0.4, dampingFraction: 0.85),
                        value: state.busy
                    )
                EarthGlobeView(spinningFast: state.busy)
                    .frame(width: 220, height: 220)
                    .offset(y: heroReady ? 0 : 18)
                    .opacity(heroReady ? 1 : 0)
            }
            .padding(.bottom, 28)

            Text(state.cleanItems.isEmpty ? "Ready to scan" : "\(ByteFormat.disk(state.cleanTotalBytes)) found")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Mole.ink)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.cleanTotalBytes)
                .opacity(heroReady ? 1 : 0)
                .offset(y: heroReady ? 0 : 10)

            HStack(spacing: 6) {
                if state.busy {
                    ProgressView().controlSize(.mini).tint(.white)
                    Text("Scanning…")
                        .foregroundColor(Theme.Mole.muted)
                } else if state.cleanItems.isEmpty {
                    Text("Caches, installers, and leftovers")
                        .foregroundColor(Theme.Mole.muted)
                    Text("·").foregroundColor(Theme.Mole.muted.opacity(0.5))
                    Button("Scan now") { Task { await state.scan() } }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.Feature.clean)
                } else {
                    Text("\(state.cleanItems.count) items in \(state.cleanCategories.count) categories")
                        .foregroundColor(Theme.Mole.muted)
                    Text("·").foregroundColor(Theme.Mole.muted.opacity(0.5))
                    Button("Scan again") { Task { await state.scan() } }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.Feature.clean)
                        .disabled(state.busy)
                }
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.top, 8)
            .animation(.easeOut(duration: 0.25), value: state.busy)
            .animation(.easeOut(duration: 0.25), value: state.cleanItems.count)

            Spacer(minLength: 24)

            Button {
                if state.cleanItems.isEmpty {
                    Task { await state.scan() }
                } else {
                    if state.selected.isEmpty { state.selectRecommendedClean() }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                        state.cleanPhase = .review
                    }
                }
            } label: {
                Text(state.cleanItems.isEmpty ? "Scan Mac" : "Review results")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Mole.ctaInk)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(Theme.Mole.cta)
                    .clipShape(Capsule())
                    .shadow(color: Color.white.opacity(0.28), radius: 22, y: 6)
            }
            .buttonStyle(PressableCapsuleStyle())
            .disabled(state.busy)
            .opacity(heroReady ? 1 : 0)
            .offset(y: heroReady ? 0 : 16)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review (category list)

    private func review(selected: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to clean")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.Mole.ink)
                    Text(reviewSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Mole.muted)
                        .lineLimit(2)
                        .contentTransition(.opacity)
                        .animation(.easeOut(duration: 0.2), value: state.selected.count)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        Task { await state.scan() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Mole.muted)
                            .frame(width: 34, height: 34)
                            .background(Theme.Mole.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.Mole.line, lineWidth: 1))
                            .rotationEffect(.degrees(state.busy ? 360 : 0))
                            .animation(
                                state.busy
                                    ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                                    : .default,
                                value: state.busy
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(state.busy)
                    .help("Scan again")

                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            state.cleanPhase = .hero
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Mole.muted)
                            .frame(width: 34, height: 34)
                            .background(Theme.Mole.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.Mole.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Back")
                }
            }
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(state.cleanCategories.enumerated()), id: \.element.id) { idx, cat in
                        CleanCategoryRow(
                            category: cat,
                            selected: selected,
                            dark: true,
                            expanded: Binding(
                                get: { expanded.contains(cat.name) },
                                set: { on in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                        if on { expanded.insert(cat.name) } else { expanded.remove(cat.name) }
                                    }
                                }
                            )
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity
                        ))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.88).delay(Double(idx) * 0.04),
                            value: state.cleanCategories.count
                        )
                    }
                }
                .padding(.bottom, 8)
            }

            reviewFooter
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var reviewSubtitle: String {
        let gb = ByteFormat.disk(state.selectedBytes > 0 ? state.selectedBytes : state.cleanTotalBytes)
        let holding = holdingApps.prefix(2).joined(separator: ", ")
        var parts = [
            "\(gb) cleanable",
            "\(state.selected.isEmpty ? state.cleanItems.count : state.selected.count) items",
            "\(state.cleanCategories.count) categories",
        ]
        if !holding.isEmpty {
            parts.append("\(holding) holding cache")
        }
        return parts.joined(separator: " · ")
    }

    private var holdingApps: [String] {
        // Best-effort: pick distinct top-level names from selected (or all) cache paths.
        let paths = state.selected.isEmpty
            ? state.cleanItems.map(\.path)
            : state.cleanItems.filter { state.selected.contains($0.path) }.map(\.path)
        var seen = Set<String>()
        var names: [String] = []
        for p in paths {
            let name = URL(fileURLWithPath: p).lastPathComponent
                .replacingOccurrences(of: ".cache", with: "")
            if name.count > 2, seen.insert(name).inserted {
                names.append(name)
            }
            if names.count >= 3 { break }
        }
        return names
    }

    private var reviewFooter: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("\(state.selected.count) selected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Mole.ink)
                Text("·").foregroundColor(Theme.Mole.muted.opacity(0.5))
                Button("All") { state.selectAllClean() }
                    .buttonStyle(.plain)
                Text("·").foregroundColor(Theme.Mole.muted.opacity(0.5))
                Button("None") { state.selected.removeAll() }
                    .buttonStyle(.plain)
                Text("·").foregroundColor(Theme.Mole.muted.opacity(0.5))
                Button("Recommended") { state.selectRecommendedClean() }
                    .buttonStyle(.plain)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.Mole.link)

            Spacer()

            Button {
                state.confirmTrash = true
            } label: {
                Text("\(state.cacheRemovalMode == "permanent" ? "Permanently clean" : "Move to Trash") · \(ByteFormat.disk(state.selectedBytes))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Mole.ctaInk)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(state.selected.isEmpty ? Theme.Mole.surface2 : Theme.Mole.cta)
                    .clipShape(Capsule())
                    .animation(.easeOut(duration: 0.2), value: state.selectedBytes)
            }
            .buttonStyle(PressableCapsuleStyle())
            .disabled(state.selected.isEmpty || state.busy)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

/// Moon — AI Cleanup & Care (on-demand scan).
struct AICleanupView: View {
    @Environment(AppState.self) private var state

    private var bands: [(String, String, [ScanItem])] {
        let order = [("caches", "Caches & old versions"), ("sessions", "Sessions & worktrees"), ("idle", "Idle tools")]
        return order.compactMap { key, title in
            let items = state.aiItems.filter { ($0.category ?? "") == key }
            return items.isEmpty ? nil : (key, title, items)
        }
    }

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Cleanup & Care")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Mole.ink)
                    Text("Caches checked by default · sessions & idle tools stay unchecked")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Mole.muted)
                }
                Spacer()
                Button {
                    withAnimation { state.showAIReview = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Mole.muted)
                        .frame(width: 34, height: 34)
                        .background(Theme.Mole.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            if state.aiItems.isEmpty && !state.busy {
                VStack(spacing: 12) {
                    Text("No AI data scanned yet")
                        .foregroundColor(Theme.Mole.muted)
                    Button("Scan AI data") { Task { await state.scanAI() } }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(bands, id: \.0) { key, title, items in
                            Text(title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.Mole.ink)
                            ForEach(items) { item in
                                HStack(spacing: 10) {
                                    Button {
                                        if state.selected.contains(item.path) {
                                            state.selected.remove(item.path)
                                        } else {
                                            state.selected.insert(item.path)
                                        }
                                    } label: {
                                        Image(systemName: state.selected.contains(item.path) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(state.selected.contains(item.path) ? Theme.Mole.link : Theme.Mole.muted)
                                    }
                                    .buttonStyle(.plain)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.Mole.ink)
                                        Text(item.path).font(.system(size: 10)).foregroundColor(Theme.Mole.muted).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(ByteFormat.disk(item.byteSize))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.Mole.muted)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                HStack {
                    Button("Scan again") { Task { await state.scanAI() } }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(state.busy)
                    Spacer()
                    Button {
                        state.confirmTrash = true
                    } label: {
                        Text("Clean selected · \(ByteFormat.disk(state.selectedBytes))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.Mole.ctaInk)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(state.selected.isEmpty ? Theme.Mole.surface2 : Theme.Mole.cta)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableCapsuleStyle())
                    .disabled(state.selected.isEmpty || state.busy)
                }
                .padding(.top, 10)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Mole.bg)
    }
}

struct PressableCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct CleanCategoryRow: View {
    let category: CleanCategory
    @Binding var selected: Set<String>
    var dark = false
    @Binding var expanded: Bool

    private var ink: Color { dark ? Theme.Mole.ink : Theme.ink }
    private var muted: Color { dark ? Theme.Mole.muted : Theme.muted }
    private var surface: Color { dark ? Theme.Mole.surface : Theme.surface }
    private var line: Color { dark ? Theme.Mole.line : Theme.line }
    private var check: Color { dark ? Theme.Mole.link : Theme.ok }

    private var selectablePaths: [String] { category.selectable.map(\.path) }
    private var selectedCount: Int { selectablePaths.filter { selected.contains($0) }.count }
    private var selectedBytes: Int64 {
        category.items.filter { selected.contains($0.path) }.reduce(0) { $0 + $1.byteSize }
    }

    private var triState: Bool? {
        if selectedCount == 0 { return false }
        if selectedCount == selectablePaths.count { return true }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    toggleCategory()
                } label: {
                    Image(systemName: checkboxSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(triState == false ? muted : check)
                }
                .buttonStyle(.plain)
                .disabled(selectablePaths.isEmpty)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(category.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ink)
                        Text("\(selectedCount)/\(category.items.count) selected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(muted)
                    }
                    Text(category.blurb)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(ByteFormat.string(selectedBytes))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(ink)
                        .monospacedDigit()
                    Text("/ \(ByteFormat.string(category.byteSize))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(muted)
                        .monospacedDigit()
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(muted)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            }

            if expanded {
                Divider().background(line)
                ForEach(category.items) { item in
                    ItemRow(item: item, selected: $selected, dark: dark)
                    Divider().background(line)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(line, lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: expanded)
        .animation(.easeOut(duration: 0.2), value: selectedCount)
    }

    private var checkboxSymbol: String {
        switch triState {
        case .some(true): return "checkmark.square.fill"
        case .some(false): return "square"
        case .none: return "minus.square.fill"
        }
    }

    private func toggleCategory() {
        if triState == true {
            for p in selectablePaths { selected.remove(p) }
        } else {
            for p in selectablePaths { selected.insert(p) }
        }
    }
}

struct SoftwareView: View {
    @Environment(AppState.self) private var state
    @State private var showSearch = false
    @State private var pulseAccent = false

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 0) {
            appsChrome(selected: $state.selected, query: $state.appsQuery)

            Group {
                switch state.softwareSegment {
                case .uninstall:
                    uninstallList(selected: $state.selected)
                case .updates:
                    updatesList
                case .startup:
                    startupList
                case .caches, .leftovers, .orphans:
                    ItemTable(items: state.currentItems, selected: $state.selected)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: state.softwareSegment)

            if state.softwareSegment == .uninstall {
                uninstallFooter(selected: $state.selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageEnter()
        .task {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulseAccent = true }
            if state.apps.isEmpty, !state.busy {
                await state.scan()
            }
        }
    }

    private func appsChrome(selected: Binding<Set<String>>, query: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(AppState.appsPrimarySegments) { s in
                        SegmentPill(
                            title: s.rawValue,
                            selected: state.softwareSegment == s
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                state.softwareSegment = s
                                state.selected.removeAll()
                            }
                            Task { await state.scan() }
                        }
                    }
                    Button {
                        Task { await state.scan(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Feature.apps)
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(state.busy ? 360 : 0))
                            .animation(
                                state.busy
                                    ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                    : .default,
                                value: state.busy
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(state.busy)
                    .help("Refresh")
                }
                .padding(3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .shadow(color: Theme.Feature.apps.opacity(pulseAccent ? 0.16 : 0.04), radius: 10, y: 2)

                Spacer()

                if state.softwareSegment == .uninstall || state.softwareSegment == .updates {
                    HStack(spacing: 10) {
                        ForEach(AppState.AppsSort.allCases) { sort in
                            Button {
                                state.appsSort = sort
                            } label: {
                                HStack(spacing: 3) {
                                    Text(sort.rawValue)
                                    if state.appsSort == sort {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                }
                                .font(.system(size: 12, weight: state.appsSort == sort ? .bold : .medium))
                                .foregroundColor(state.appsSort == sort ? Theme.ink : Theme.muted)
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            withAnimation { showSearch.toggle() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(showSearch || !state.appsQuery.isEmpty ? Theme.ink : Theme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                } else if state.softwareSegment == .startup {
                    HStack(spacing: 8) {
                        Text("Filter")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.muted)
                        Button {
                            withAnimation { showSearch.toggle() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(showSearch || !state.appsQuery.isEmpty ? Theme.ink : Theme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if showSearch, state.softwareSegment == .uninstall || state.softwareSegment == .startup || state.softwareSegment == .updates {
                TextField(state.softwareSegment == .startup ? "Filter startup items" : "Search apps", text: query)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.line, lineWidth: 1)
                    )
            }

            if state.softwareSegment == .uninstall {
                let total = state.apps.reduce(Int64(0)) { $0 + ($1.appBytes ?? $1.byteSize) }
                Text("Installed Apps  \(state.sortedApps.count) apps · \(ByteFormat.string(total))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Feature.apps.opacity(0.85))
            }
        }
        .padding(.bottom, 10)
    }

    private func uninstallList(selected: Binding<Set<String>>) -> some View {
        Group {
            if state.sortedApps.isEmpty {
                EmptyState(
                    title: state.busy ? "Scanning apps…" : "No apps found",
                    systemImage: "square.grid.2x2",
                    message: "Scan /Applications to list installed apps and leftovers."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(state.sortedApps.enumerated()), id: \.element.id) { idx, app in
                            AppsUninstallRow(app: app, selected: selected, alsoRemoveData: state.alsoRemoveData)
                                .transition(.opacity.combined(with: .offset(y: 8)))
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.88).delay(Double(idx) * 0.025),
                                    value: state.sortedApps.count
                                )
                        }
                    }
                }
            }
        }
    }

    private func uninstallFooter(selected: Binding<Set<String>>) -> some View {
        let picked = state.apps.filter { selected.wrappedValue.contains($0.path) }
        let title: String = {
            if picked.isEmpty { return "No apps selected" }
            if picked.count == 1 { return picked[0].name }
            return "\(picked[0].name) +\(picked.count - 1)"
        }()

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(title) · \(picked.count) app\(picked.count == 1 ? "" : "s") · \(ByteFormat.string(state.uninstallSelectedBytes))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)
                HStack(spacing: 12) {
                    Button {
                        state.alsoRemoveData.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: state.alsoRemoveData ? "checkmark.square.fill" : "square")
                            Text("Also remove data")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Feature.apps)
                    }
                    .buttonStyle(.plain)

                    Button("Clear selection") {
                        selected.wrappedValue.removeAll()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .disabled(picked.isEmpty)
                }
            }

            Spacer()

            Button {
                state.confirmTrash = true
            } label: {
                Text(picked.isEmpty ? "Remove" : "Remove \(picked.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Mole.ctaInk)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(picked.isEmpty ? Theme.surface2 : Theme.Mole.cta)
                    .clipShape(Capsule())
                    .shadow(color: Color.white.opacity(picked.isEmpty ? 0 : 0.18), radius: 16, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(picked.isEmpty || state.busy)
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var updatesList: some View {
        let q = state.appsQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let inApp = state.updatesInApp.filter { q.isEmpty || $0.name.lowercased().contains(q) }
        let outside = state.updatesOutside.filter { q.isEmpty || $0.name.lowercased().contains(q) }
        let current = state.upToDateApps.filter { q.isEmpty || $0.name.lowercased().contains(q) }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if !inApp.isEmpty {
                    appsSectionHeader("Update in CleanMac", count: inApp.count)
                    ForEach(inApp) { u in
                        AppsUpdateRow(item: u)
                    }
                }
                if !outside.isEmpty {
                    appsSectionHeader("Finish Outside CleanMac", count: outside.count)
                    ForEach(outside) { u in
                        AppsUpdateRow(item: u)
                    }
                }
                if !current.isEmpty {
                    appsSectionHeader("Up to Date Apps", count: current.count)
                    ForEach(current) { app in
                        AppsUpToDateRow(app: app)
                    }
                }
                if inApp.isEmpty, outside.isEmpty, current.isEmpty {
                    EmptyState(
                        title: state.busy ? "Checking…" : "No updates",
                        systemImage: "arrow.triangle.2.circlepath",
                        message: "Homebrew outdated apps and up-to-date installs appear here."
                    )
                }
            }
        }
        .task {
            if state.apps.isEmpty { await state.scanAppsQuiet() }
        }
    }

    private var startupList: some View {
        let q = state.appsQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let items = state.startupItems.filter {
            q.isEmpty || $0.name.lowercased().contains(q) || $0.detail?.lowercased().contains(q) == true
        }
        let login = items.filter { $0.kind == "login-item" }
        let background = items.filter { $0.kind == "background-item" }
        let services = items.filter { $0.kind == "launch-agent" || $0.kind == "launch-daemon" }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if !login.isEmpty {
                    appsSectionHeader("Login items", count: login.count)
                    ForEach(login) { s in
                        AppsStartupRow(item: s)
                    }
                }
                if !background.isEmpty {
                    appsSectionHeader("Allow in the background", count: background.count)
                    ForEach(background) { s in
                        AppsStartupRow(item: s)
                    }
                }
                if !services.isEmpty {
                    appsSectionHeader("Background services", count: services.count)
                    ForEach(services) { s in
                        AppsStartupRow(item: s)
                    }
                }
                if login.isEmpty, background.isEmpty, services.isEmpty {
                    EmptyState(
                        title: state.busy ? "Scanning…" : "No startup items",
                        systemImage: "power",
                        message: "Login items and LaunchAgents appear here."
                    )
                }
            }
        }
    }

    private func appsSectionHeader(_ title: String, count: Int) -> some View {
        Text("\(title)  \(count)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.muted)
            .padding(.top, 4)
    }
}

struct AppsUpdateRow: View {
    @Environment(AppState.self) private var state
    let item: UpdateItem

    private var sourceLabel: String {
        switch item.source {
        case "mas": return "App Store"
        case "homebrew-cask", "homebrew-formula": return "Homebrew"
        default: return "Website"
        }
    }

    private var versionLine: String? {
        if let c = item.current, let l = item.latest, !c.isEmpty, !l.isEmpty {
            return "\(c) -> \(l)"
        }
        return item.latest ?? item.detail
    }

    private var actionTitle: String {
        if item.source == "mas" || (item.group ?? "") == "outside" { return "Download" }
        return "Update"
    }

    private var iconPath: String? {
        state.apps.first { $0.name.localizedCaseInsensitiveCompare(item.name) == .orderedSame }?.path
            ?? state.apps.first { $0.name.lowercased().contains(item.name.lowercased()) }?.path
    }

    var body: some View {
        HStack(spacing: 12) {
            appIcon
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.ink)
                    Text(sourceLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.surface2)
                        .clipShape(Capsule())
                }
                if let versionLine {
                    Text(versionLine)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.danger)
                }
            }
            Spacer()
            Button("Ignore Updates") { state.ignoreUpdate(item) }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.muted)
            Button(actionTitle) { state.openUpdate(item) }
                .buttonStyle(SoftButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var appIcon: some View {
        if let path = iconPath {
            Image(nsImage: AppMeta.icon(path))
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.surface2)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(Theme.muted)
                }
        }
    }
}

struct AppsUpToDateRow: View {
    let app: ScanItem

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: AppMeta.icon(app.path))
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Text("\(AppMeta.version(app.path) ?? "—") · \(ByteFormat.string(app.appBytes ?? app.byteSize)) · \(AppMeta.relative(AppMeta.lastUsed(app.path)).replacingOccurrences(of: "active ", with: "opened "))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct AppsStartupRow: View {
    @Environment(AppState.self) private var state
    let item: StartupItem

    private var canToggle: Bool { !item.path.hasPrefix("login:") }

    var body: some View {
        HStack(spacing: 12) {
            startupIcon
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                Text(item.detail ?? item.kind)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { item.enabled },
                set: { on in
                    guard canToggle else { return }
                    Task { await state.setStartup(path: item.path, enabled: on) }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .disabled(!canToggle)
            .opacity(canToggle ? 1 : 0.45)
            .help(canToggle ? "Enable or disable" : "Manage in System Settings → Login Items")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var startupIcon: some View {
        let appPath = state.apps.first {
            item.name.localizedCaseInsensitiveContains($0.name) || $0.name.localizedCaseInsensitiveContains(item.name)
        }?.path
        if let appPath {
            Image(nsImage: AppMeta.icon(appPath))
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.surface2)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: item.kind == "login-item" ? "person.crop.circle" : "gearshape.fill")
                        .foregroundColor(Theme.muted)
                }
        }
    }
}

struct AppsUninstallRow: View {
    let app: ScanItem
    @Binding var selected: Set<String>
    var alsoRemoveData: Bool

    private var isOn: Binding<Bool> {
        Binding(
            get: { selected.contains(app.path) },
            set: { on in
                if on { selected.insert(app.path) } else { selected.remove(app.path) }
            }
        )
    }

    private var appBytes: Int64 { app.appBytes ?? app.byteSize }

    private var removeBytes: Int64 {
        alsoRemoveData ? appBytes + (app.leftoverBytes ?? 0) : appBytes
    }

    private var metaLine: String {
        let ver = AppMeta.version(app.path) ?? "—"
        let used = AppMeta.relative(AppMeta.lastUsed(app.path))
        return "\(ver) · \(ByteFormat.string(appBytes)) app · \(used)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: AppMeta.icon(app.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                Text(metaLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteFormat.string(appBytes))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.ink)
                if alsoRemoveData, (app.leftoverBytes ?? 0) > 0 {
                    Text("+\(ByteFormat.string(app.leftoverBytes ?? 0)) data")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Feature.apps)
                } else if (app.leftoverBytes ?? 0) > 0 {
                    Text("\(ByteFormat.string(app.leftoverBytes ?? 0)) data")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.muted.opacity(0.7))

            CheckMark(isOn: isOn, disabled: false, accent: Theme.Feature.apps)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(selected.contains(app.path) ? Theme.Feature.apps.opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
    }
}

struct AppsView: View {
    var body: some View { SoftwareView() }
}

struct AnalyzeView: View {
    @Environment(AppState.self) private var state
    @State private var spin = false

    private var children: [TreeNode] {
        (state.treemap?.children ?? []).sorted { $0.byteSize > $1.byteSize }
    }

    private var folderBytes: Int64 {
        state.treemap?.byteSize ?? children.reduce(0) { $0 + $1.byteSize }
    }

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 2) {
                ForEach(AppState.AnalyzeSegment.allCases) { s in
                    SegmentPill(title: s.rawValue, selected: state.analyzeSegment == s) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            state.analyzeSegment = s
                            state.selected.removeAll()
                        }
                        Task { await state.scan() }
                    }
                }
                Spacer(minLength: 8)
                Button {
                    Task { await state.scan(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Feature.analyze)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(state.busy)
                .help("Refresh")
            }
            .padding(3)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())

            Group {
                switch state.analyzeSegment {
                case .overview:
                    OverviewPane(overview: state.overview)
                case .map:
                    HStack(spacing: 14) {
                        analyzeSidebar
                        analyzeMain
                    }
                case .large:
                    ItemTable(items: state.large, selected: $state.selected)
                case .dupes:
                    DupesPane(groups: state.dupes, selected: $state.selected)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: state.analyzeSegment)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageEnter()
        .task {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { spin = true }
            if state.treemap == nil || state.overview == nil {
                await state.scan()
            }
        }
    }

    private var analyzeSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Theme.Feature.analyze.opacity(state.busy ? 0.45 : 0.28),
                                    Theme.Feature.surface2(for: .analyze),
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 48
                            )
                        )
                        .frame(width: 88, height: 88)
                        .scaleEffect(state.busy ? 1.06 : 1)
                        .animation(
                            state.busy
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                : .spring(response: 0.4, dampingFraction: 0.85),
                            value: state.busy
                        )
                    // Jupiter (mole.fit Analyze) — banded warm sphere
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.85, green: 0.72, blue: 0.55),
                                    Color(red: 0.64, green: 0.42, blue: 0.28),
                                    Color(red: 0.90, green: 0.82, blue: 0.68),
                                    Color(red: 0.55, green: 0.38, blue: 0.28),
                                    Color(red: 0.78, green: 0.58, blue: 0.40),
                                    Color(red: 0.85, green: 0.72, blue: 0.55),
                                ],
                                center: .center
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .shadow(color: Theme.Feature.analyze.opacity(0.45), radius: 12, y: 4)
                }
                Spacer()
            }
            .padding(.top, 8)

            Text("\(children.count) items, \(ByteFormat.disk(folderBytes))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.ink)
                .frame(maxWidth: .infinity)

            Text("Current Folder")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.muted)
                .padding(.top, 4)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(children) { child in
                        Button {
                            state.analyzeSelectedPath = child.path
                            if child.isDirectory == true {
                                state.treemapPath = child.path
                                Task { await state.scan(force: true) }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: child.isDirectory == true ? "folder.fill" : "doc.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Feature.analyze)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(child.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.ink)
                                        .lineLimit(1)
                                    Text(ByteFormat.disk(child.byteSize))
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.muted)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Theme.muted.opacity(0.7))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(state.analyzeSelectedPath == child.path
                                          ? Theme.Feature.analyze.opacity(0.22) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Open") { state.reveal(child.path) }
                            if child.isDirectory == true {
                                Button("Open in Analyze") {
                                    state.treemapPath = child.path
                                    Task { await state.scan(force: true) }
                                }
                            }
                            Button("Move to Trash", role: .destructive) {
                                state.selected = [child.path]
                                state.confirmTrash = true
                            }
                        }
                    }
                }
            }

            Text("Right-click: Open / Trash")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.muted)
                .padding(.bottom, 4)
        }
        .padding(14)
        .frame(width: 240)
        .background(Theme.Feature.surface(for: .analyze))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Feature.analyze.opacity(0.22), lineWidth: 1)
        )
    }

    private var analyzeMain: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                breadcrumbBar
                Spacer(minLength: 8)
                diskMeter
                Button {
                    Task { await state.scan(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 30, height: 30)
                        .background(Theme.Feature.surface2(for: .analyze))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(state.busy)
                .help("Refresh")
            }

            if state.treemap == nil {
                EmptyState(
                    title: state.busy ? "Scanning disk…" : "Disk map",
                    systemImage: "square.grid.3x3",
                    message: "Scan to map folder sizes."
                )
            } else if children.isEmpty {
                EmptyState(title: "Empty folder", systemImage: "folder", message: "No measurable items here.")
            } else {
                TreemapCanvas(nodes: children, selectedPath: state.analyzeSelectedPath) { node in
                    state.analyzeSelectedPath = node.path
                    if node.isDirectory == true {
                        state.treemapPath = node.path
                        Task { await state.scan(force: true) }
                    } else {
                        state.reveal(node.path)
                    }
                } onContextReveal: { node in
                    state.reveal(node.path)
                } onContextTrash: { node in
                    state.selected = [node.path]
                    state.confirmTrash = true
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(.spring(response: 0.4, dampingFraction: 0.86), value: state.treemapPath)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Feature.surface(for: .analyze))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Feature.analyze.opacity(0.22), lineWidth: 1)
        )
    }

    private var breadcrumbBar: some View {
        let crumbs = Self.breadcrumbs(for: state.treemapPath)
        return HStack(spacing: 6) {
            ForEach(Array(crumbs.enumerated()), id: \.offset) { idx, crumb in
                if idx > 0 {
                    Text(">")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted.opacity(0.6))
                }
                Button(crumb.name) {
                    state.treemapPath = crumb.path
                    Task { await state.scan(force: true) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: idx == crumbs.count - 1 ? .bold : .medium))
                .foregroundColor(idx == crumbs.count - 1 ? Theme.ink : Theme.muted)
            }
        }
        .lineLimit(1)
    }

    private var diskMeter: some View {
        let used = state.overview?.usedBytes ?? 0
        let total = max(state.overview?.totalBytes ?? 1, 1)
        let folder = folderBytes
        return HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Feature.surface2(for: .analyze))
                    Capsule()
                        .fill(Theme.Feature.analyze.opacity(0.85))
                        .frame(width: max(4, geo.size.width * CGFloat(used) / CGFloat(total)))
                }
            }
            .frame(width: 72, height: 6)
            Text("Files \(ByteFormat.disk(folder)) · Used \(ByteFormat.disk(used)) / \(ByteFormat.disk(total))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
        }
    }

    private static func breadcrumbs(for path: String) -> [(name: String, path: String)] {
        let home = NSHomeDirectory()
        var crumbs: [(String, String)] = []
        if path == "/" {
            return [("Whole Disk", "/")]
        }
        if path.hasPrefix(home) {
            crumbs.append(("Home", home))
            let rest = String(path.dropFirst(home.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !rest.isEmpty {
                var cur = home
                for part in rest.split(separator: "/") {
                    cur = (cur as NSString).appendingPathComponent(String(part))
                    crumbs.append((String(part), cur))
                }
            }
            return crumbs
        }
        crumbs.append(("Whole Disk", "/"))
        var cur = ""
        for part in path.split(separator: "/") {
            cur += "/" + part
            crumbs.append((String(part), cur))
        }
        return crumbs
    }
}

struct TreemapCanvas: View {
    let nodes: [TreeNode]
    var selectedPath: String?
    var onOpen: (TreeNode) -> Void
    var onContextReveal: (TreeNode) -> Void
    var onContextTrash: (TreeNode) -> Void

    private let palette: [Color] = [
        Color(red: 0.83, green: 0.72, blue: 0.55),
        Color(red: 0.72, green: 0.58, blue: 0.42),
        Color(red: 0.78, green: 0.45, blue: 0.32),
        Color(red: 0.86, green: 0.70, blue: 0.38),
        Color(red: 0.55, green: 0.50, blue: 0.44),
    ]

    var body: some View {
        GeometryReader { geo in
            let total = max(nodes.reduce(Int64(0)) { $0 + $1.byteSize }, 1)
            let primary = nodes.first
            let rest = Array(nodes.dropFirst().prefix(4))
            let otherCount = max(0, nodes.count - 1 - rest.count)
            let otherBytes = nodes.dropFirst().dropFirst(rest.count).reduce(Int64(0)) { $0 + $1.byteSize }
            let rightW = geo.size.width * 0.38
            let leftW = geo.size.width - rightW - 8

            HStack(alignment: .top, spacing: 8) {
                if let primary {
                    tile(primary, color: palette[0], selected: selectedPath == primary.path)
                        .frame(width: leftW, height: geo.size.height)
                }
                VStack(spacing: 8) {
                    ForEach(Array(rest.enumerated()), id: \.element.id) { idx, node in
                        tile(node, color: palette[(idx + 1) % palette.count], selected: selectedPath == node.path)
                            .frame(maxHeight: .infinity)
                    }
                    if otherCount > 0 {
                        otherTile(count: otherCount, bytes: otherBytes, color: palette[4])
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: rightW, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .opacity(total > 0 ? 1 : 0.5)
        }
    }

    private func tile(_ node: TreeNode, color: Color, selected: Bool) -> some View {
        Button {
            onOpen(node)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(selected ? 1 : 0.92))
                VStack(spacing: 8) {
                    Image(systemName: node.isDirectory == true ? "folder.fill" : "doc.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Theme.ink.opacity(0.75))
                    Text(node.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(ByteFormat.disk(node.byteSize))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.ink.opacity(0.7))
                }
                .padding(12)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") { onContextReveal(node) }
            Button("Move to Trash", role: .destructive) { onContextTrash(node) }
        }
    }

    private func otherTile(count: Int, bytes: Int64, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.85))
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.ink.opacity(0.7))
                Text("\(count) items")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.ink)
                Text(ByteFormat.disk(bytes))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.ink.opacity(0.7))
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
    var dark = false
    @Environment(AppState.self) private var state

    private var ink: Color { dark ? Theme.Mole.ink : Theme.ink }
    private var muted: Color { dark ? Theme.Mole.muted : Theme.muted }

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
            CheckMark(isOn: isOn, disabled: blocked, accent: dark ? Theme.Mole.link : Theme.Feature.apps)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ink)
                    .lineLimit(1)
                Text(item.explanation ?? item.path)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            SafetyBadge(safety: item.safety)
            if item.isCacheLeftover {
                Text("CACHE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(dark ? Theme.Mole.ctaInk : Theme.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(dark ? Theme.Mole.link : Theme.accent)
                    .clipShape(Capsule())
            }

            Text(ByteFormat.string(item.byteSize))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(ink)
                .monospacedDigit()
                .frame(width: 68, alignment: .trailing)
                .fixedSize()

            Button("Reveal") { state.reveal(item.path) }
                .buttonStyle(SoftButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(selected.contains(item.path)
            ? (dark ? Theme.Mole.link.opacity(0.18) : Theme.accentSoft)
            : Color.clear)
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
