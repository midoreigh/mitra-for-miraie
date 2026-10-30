import AppIntents
import ServiceManagement
import SwiftUI
import MitraKit

struct SettingsView: View {
    @Environment(ACStore.self) private var store
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("MirAIe account", value: SecretStore.credentials?.username ?? "Not signed in")
                LabeledContent("Air conditioners", value: store.devices.map(\.name).joined(separator: ", "))
                if store.phase != .signedOut {
                    Button("Sign Out", role: .destructive) { store.signOut() }
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }))
                Picker("Default AC for Siri and widgets", selection: Binding(
                    get: { store.selected?.id ?? "" },
                    set: { store.selectedId = $0 }
                )) {
                    ForEach(store.devices) { Text($0.name).tag($0.id) }
                }
                .disabled(store.devices.count < 2)
            }

            ForEach(store.devices) { device in
                let capabilities = store.capabilities[device.id] ?? ACCapabilities()
                Section {
                    Toggle("Heating", isOn: Binding(get: { capabilities.heat }, set: { on in
                        var updated = capabilities
                        updated.heat = on
                        store.setCapabilities(updated, for: device.id)
                    }))
                    Toggle("nanoe X air purifier", isOn: Binding(get: { capabilities.nanoe }, set: { on in
                        var updated = capabilities
                        updated.nanoe = on
                        store.setCapabilities(updated, for: device.id)
                    }))
                    Toggle("Converti7 cooling levels", isOn: Binding(get: { capabilities.converti }, set: { on in
                        var updated = capabilities
                        updated.converti = on
                        store.setCapabilities(updated, for: device.id)
                    }))
                } header: {
                    Text("\(device.name) features")
                } footer: {
                    Text("MirAIe doesn't say which features an AC has. Mitra for MirAIe turns Heating and nanoe X on when the AC reports using them; switch features on or off to match your model.")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Self.siriExamples, id: \.self) { phrase in
                        Label("“\(phrase)”", systemImage: "waveform")
                    }
                }
                .foregroundStyle(.secondary)
                Button("Open Shortcuts") {
                    NSWorkspace.shared.open(URL(string: "shortcuts://")!)
                }
            } header: {
                Text("Siri & Shortcuts")
            } footer: {
                Text("Mitra for MirAIe's actions also appear in the Shortcuts app, Spotlight and Control Center.")
            }

            Section("Widgets") {
                Text("Right-click the desktop and choose Edit Widgets, or open Notification Centre and click Edit Widgets, then search for Mitra for MirAIe.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private static let siriExamples = [
        "Turn on the AC in Mitra for MirAIe",
        "Set the Mitra for MirAIe temperature",
        "Make it cooler with Mitra for MirAIe",
        "Switch Mitra for MirAIe to Dry",
        "What's the AC doing in Mitra for MirAIe",
    ]

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSSound.beep()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
