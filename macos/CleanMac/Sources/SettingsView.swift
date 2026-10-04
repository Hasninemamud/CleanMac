import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.system(size: 16, weight: .bold)).foregroundColor(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(SoftButtonStyle())
            }
            .padding(16)
            Picker("", selection: $tab) {
                Text("General").tag(0)
                Text("Whitelist").tag(1)
                Text("Doctor").tag(2)
                Text("History").tag(3)
                Text("Tools").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            Group {
                switch tab {
                case 1: whitelistPane
                case 2: doctorPane
                case 3: historyPane
                case 4: toolsPane
                default: generalPane
                }
            }
            .padding(16)
            Spacer(minLength: 0)
        }
        .background(Theme.Mole.bg)
        .preferredColorScheme(.dark)
        .task { await state.loadSettingsData() }
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CleanMac keeps deletes in Trash and blocks system paths.")
                .foregroundColor(Theme.muted)
            Text("Menu bar HUD shows health and top processes while the app runs.")
                .foregroundColor(Theme.muted)
            Toggle("Keep display awake", isOn: Binding(
                get: { state.keepAwake },
                set: { _ in state.toggleKeepAwake() }
            ))
            .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var whitelistPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Excluded paths (not offered in scans)").foregroundColor(Theme.muted).font(.system(size: 12))
            ScrollView {
                ForEach(state.whitelist, id: \.self) { p in
                    HStack {
                        Text(p).lineLimit(1).foregroundColor(Theme.ink).font(.system(size: 12))
                        Spacer()
                        Button("Remove") { Task { await state.removeWhitelist(p) } }
                            .buttonStyle(SoftButtonStyle())
                    }
                }
            }
            Button("Add folder…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = true
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    Task { await state.addWhitelist(url.path) }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var doctorPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(state.doctorChecks) { c in
                HStack {
                    Circle().fill(c.status == "ok" ? Theme.ok : (c.status == "warn" ? Theme.warn : Theme.danger)).frame(width: 8, height: 8)
                    VStack(alignment: .leading) {
                        Text(c.title).foregroundColor(Theme.ink).font(.system(size: 13, weight: .semibold))
                        Text(c.detail).foregroundColor(Theme.muted).font(.system(size: 11))
                    }
                }
            }
            Button("Re-run Doctor") { Task { await state.loadSettingsData() } }
                .buttonStyle(SoftButtonStyle())
        }
    }

    private var historyPane: some View {
        ScrollView {
            ForEach(state.history) { e in
                HStack {
                    Text(e.action).foregroundColor(Theme.accent).font(.system(size: 12, weight: .bold))
                    Text(e.time).foregroundColor(Theme.muted).font(.system(size: 11))
                    Spacer()
                    if let d = e.detail, !d.isEmpty {
                        Text(d).foregroundColor(Theme.ink).font(.system(size: 11)).lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var toolsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Clean screen") { state.showCleanScreen = true; dismiss() }
                .buttonStyle(SoftButtonStyle())
            Button(state.keepAwake ? "Allow sleep" : "Keep display awake") {
                state.toggleKeepAwake()
            }
            .buttonStyle(SoftButtonStyle())
            Text("Privacy: \(PrivacyStatus.summary)")
                .foregroundColor(Theme.muted)
                .font(.system(size: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
