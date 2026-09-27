import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            topBar
            pageHead
            content
            if !state.selected.isEmpty {
                selectionDock
            }
        }
        .frame(minWidth: 920, idealWidth: 1020, maxWidth: 1280,
               minHeight: 600, idealHeight: 680, maxHeight: 900)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .alert("Move to Trash?", isPresented: $state.confirmTrash) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                Task { await state.trashSelected() }
            }
        } message: {
            Text("\(state.selected.count) items · \(ByteFormat.string(state.selectedBytes))")
                .foregroundStyle(Theme.ink)
        }
        .alert("Error", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .onAppear {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // Brand | centered nav | status  — no competing maxWidth infinity
    private var topBar: some View {
        ZStack {
            Theme.rail
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    BrandLogo(size: 26)
                    Text("CleanMac")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.ink)
                }
                .fixedSize()

                Spacer(minLength: 8)

                Text(state.statusLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(state.busy ? Theme.accent : Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 140, alignment: .trailing)

                if state.busy {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Theme.accent)
                }
            }
            .padding(.leading, 72)
            .padding(.trailing, 16)

            HStack(spacing: 2) {
                ForEach(AppState.NavSection.allCases) { s in
                    SegmentPill(title: s.rawValue, selected: state.section == s) {
                        state.section = s
                        state.selected.removeAll()
                    }
                }
            }
            .padding(3)
            .background(Color.black.opacity(0.35))
            .clipShape(Capsule())
        }
        .frame(height: 50)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    private var pageHead: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pageTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.ink)
                Text(pageSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            if state.busy {
                Button("Stop") {
                    state.stop()
                }
                .buttonStyle(SoftButtonStyle())
                .fixedSize()
            }
            Button(scanLabel) {
                Task { await state.scan() }
            }
            .buttonStyle(PrimaryButtonStyle(disabled: state.busy))
            .disabled(state.busy)
            .fixedSize()
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
            case .apps: AppsView()
            case .analyze: AnalyzeView()
            case .optimize: OptimizeView()
            case .status: StatusView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    private var selectionDock: some View {
        HStack(spacing: 10) {
            Text("\(state.selected.count) selected · \(ByteFormat.string(state.selectedBytes))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.ink)
            Spacer()
            Button("Clear") { state.selected.removeAll() }
                .buttonStyle(SoftButtonStyle())
            Button("Move to Trash") { state.confirmTrash = true }
                .buttonStyle(DangerButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    private var pageTitle: String {
        switch state.section {
        case .clean: return "Clean"
        case .apps: return "Apps"
        case .analyze: return "Analyze"
        case .optimize: return "Optimize"
        case .status: return "Status"
        }
    }

    private var pageSubtitle: String {
        switch state.section {
        case .clean: return "Junk, installers, and project artifacts"
        case .apps: return "Installed apps and orphaned leftovers"
        case .analyze: return "Disk map, large files, and duplicates"
        case .optimize: return "Light maintenance — confirm before running"
        case .status: return "Live meters · refreshes every 2s"
        }
    }

    private var scanLabel: String {
        switch state.section {
        case .clean:
            switch state.cleanSegment {
            case .junk: return "Scan"
            case .installers: return "Find installers"
            case .purge: return "Find artifacts"
            }
        case .apps: return "Scan leftovers"
        case .analyze:
            switch state.analyzeSegment {
            case .overview: return "Scan disk map"
            case .large: return "Scan ≥50 MB"
            case .dupes: return "Find duplicates"
            }
        case .optimize: return "Preview"
        case .status: return "Refresh"
        }
    }
}
