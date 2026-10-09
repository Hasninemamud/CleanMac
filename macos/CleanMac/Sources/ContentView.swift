import SwiftUI
import AppKit
import IOKit.pwr_mgt

struct ContentView: View {
    @Environment(AppState.self) private var state
    @Namespace private var navNS

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            topBar
            if !selfContainedSection {
                pageHead
            }
            content
            if !selfContainedSection, !state.selected.isEmpty {
                selectionDock
            }
        }
        .frame(minWidth: 920, idealWidth: 1020, maxWidth: 1280,
               minHeight: 600, idealHeight: 680, maxHeight: 900)
        .background(PlanetCanvas(section: state.section))
        .preferredColorScheme(state.appearanceDark ? .dark : .light)
        .id(state.appearanceTick)
        .animation(Theme.Motion.section, value: state.section)
        .animation(.easeInOut(duration: 0.28), value: state.appearanceTick)
        .onChange(of: state.section) { _, section in
            // Remounted pages also .task; Status always recalculates live metrics.
            if section == .status {
                Task { await state.scan(quiet: true) }
            }
        }
        .alert(state.deletesPermanently ? "Delete permanently?" : "Move to Trash?", isPresented: $state.confirmTrash) {
            Button("Cancel", role: .cancel) {}
            Button(state.deletesPermanently ? "Delete" : "Move to Trash", role: .destructive) {
                Task { await state.trashSelected() }
            }
        } message: {
            Text("\(state.selected.count) items · \(ByteFormat.string(state.selectedBytes))")
        }
        .alert("Error", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                state.errorMessage = nil
                if state.statusLine == "Error" { state.statusLine = "Ready" }
            }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .sheet(isPresented: $state.showSettings) {
            SettingsView()
                .environment(state)
                .frame(width: 560, height: 480)
        }
        .sheet(isPresented: $state.showCleanScreen) {
            CleanScreenView { state.showCleanScreen = false }
                .frame(minWidth: 800, minHeight: 600)
        }
        .onAppear {
            Theme.useDark = state.appearanceDark
            NSApp.appearance = NSAppearance(named: state.appearanceDark ? .darkAqua : .aqua)
        }
    }

    private var topBar: some View {
        let accent = Theme.Feature.accent(for: state.section)
        return ZStack {
            Theme.rail
                .animation(.easeInOut(duration: 0.3), value: state.section)
            HStack(spacing: 10) {
                Spacer(minLength: 8)
                if state.busy {
                    ProgressView().controlSize(.mini).tint(accent)
                }
                Text(state.statusLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(state.busy ? accent : Theme.muted)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .trailing)
                Button {
                    state.showSettings = true
                    Task { await state.loadSettingsData() }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
                .help("Settings")
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        state.appearanceDark.toggle()
                    }
                } label: {
                    Image(systemName: state.appearanceDark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .symbolEffect(.bounce, value: state.appearanceTick)
                }
                .buttonStyle(.plain)
                .help(state.appearanceDark ? "Light theme" : "Dark theme")
            }
            .padding(.trailing, 16)
            .animation(.easeOut(duration: 0.2), value: state.busy)

            // Centered planet nav (mock: icon + label pills)
            HStack(spacing: 2) {
                ForEach(AppState.NavSection.allCases) { s in
                    SegmentPill(
                        title: s.rawValue,
                        selected: state.section == s,
                        accent: Theme.Feature.accent(for: s),
                        namespace: navNS,
                        matchID: "mainNav"
                    ) {
                        if state.section != s {
                            state.stop()
                        }
                        withAnimation(Theme.Motion.snappy) {
                            state.section = s
                            state.selected.removeAll()
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Theme.useDark ? Color.white.opacity(0.06) : Color.white.opacity(0.55))
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            )
            .animation(Theme.Motion.snappy, value: state.section)
        }
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1)
        }
    }

    private var pageHead: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pageTitle)
                    .font(Theme.Typeface.title())
                    .foregroundColor(Theme.ink)
                Text(pageSubtitle)
                    .font(Theme.Typeface.body(12))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            if state.section == .status {
                Button(state.keepAwake ? "Allow sleep" : "Keep awake") {
                    state.toggleKeepAwake()
                }
                .buttonStyle(SoftButtonStyle())
                Button("Clean screen") { state.showCleanScreen = true }
                    .buttonStyle(SoftButtonStyle())
            }
            if state.busy {
                Button("Stop") { state.stop() }
                    .buttonStyle(SoftButtonStyle())
            }
            Button(scanLabel) {
                Task { await state.scan() }
            }
            .buttonStyle(PrimaryButtonStyle(disabled: state.busy))
            .disabled(state.busy)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch state.section {
            case .clean: CleanView()
            case .software: SoftwareView()
            case .analyze: AnalyzeView()
            case .optimize: OptimizeView()
            case .status: StatusView()
            }
        }
        .id(state.section)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.985)),
            removal: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.99))
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, selfContainedSection ? 28 : 22)
        .padding(.top, selfContainedSection ? 18 : 0)
        .padding(.bottom, selfContainedSection ? 18 : 14)
        .animation(Theme.Motion.section, value: state.section)
    }

    private var selfContainedSection: Bool {
        state.section == .clean || state.section == .software
            || state.section == .optimize || state.section == .analyze
            || state.section == .status
    }

    private var selectionDock: some View {
        HStack(spacing: 10) {
            Text("\(state.selected.count) selected · \(ByteFormat.string(state.selectedBytes))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.ink)
            Spacer()
            Button("Whitelist") {
                Task {
                    for p in state.selected { await state.addWhitelist(p) }
                    state.selected.removeAll()
                    state.statusLine = "Added to whitelist"
                }
            }
            .buttonStyle(SoftButtonStyle())
            Button("Clear") { state.selected.removeAll() }
                .buttonStyle(SoftButtonStyle())
            Button(state.deletesPermanently ? "Delete" : "Move to Trash") { state.confirmTrash = true }
                .buttonStyle(DangerButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.Feature.panelFill(for: state.section))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.Feature.accent(for: state.section).opacity(0.28))
                .frame(height: 1)
        }
    }

    private var pageTitle: String { state.section.rawValue }

    private var pageSubtitle: String {
        switch state.section {
        case .clean: return "Caches, logs, installers, artifacts — review before permanent delete"
        case .software: return "Caches, leftovers, uninstall, updates, startup"
        case .analyze: return "Disk map, treemap drill-down, large files, duplicates"
        case .optimize: return "Maintenance catalog — preview, then confirm"
        case .status: return "Live meters · menu bar HUD · utilities"
        }
    }

    private var scanLabel: String {
        switch state.section {
        case .clean: return "Scan"
        case .software:
            switch state.softwareSegment {
            case .updates: return "Check updates"
            case .startup: return "Scan startup"
            default: return "Scan software"
            }
        case .analyze:
            switch state.analyzeSegment {
            case .overview: return "Scan disk map"
            case .map: return "Scan folder"
            case .large: return "Scan ≥50 MB"
            case .dupes: return "Find duplicates"
            }
        case .optimize: return "Preview"
        case .status: return "Refresh"
        }
    }
}

struct CleanScreenView: View {
    var onClose: () -> Void
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Clean screen")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.muted)
                Text("Press Esc or click Close")
                    .foregroundColor(Theme.muted.opacity(0.7))
                Button("Close", action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .onExitCommand(perform: onClose)
    }
}
