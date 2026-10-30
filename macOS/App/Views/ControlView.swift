import SwiftUI
import MitraKit
import MitraUI

struct ControlView: View {
    @Environment(ACStore.self) private var store
    private var state: ACState { store.state }
    private var tint: Color { state.mode.tint }

    var body: some View {
        VStack(spacing: 0) {
            hero
            VStack(spacing: 12) {
                if !state.isOnline { offlineBanner }
                Group {
                    fanSpeeds
                    modes
                    features
                }
                .disabled(!store.canControl)
                .opacity(state.isOn ? 1 : 0.55)
            }
            .padding(16)
        }
    }

    // MARK: - Hero

    /// The AC edge to edge with its air, the room temperature over it and the louver controls
    /// along the bottom.
    private var hero: some View {
        ZStack(alignment: .top) {
            heroBackground
            ACUnitView(state: state, statusLight: connection.color, statusText: connection.text,
                       onStatusLightTap: store.isPreviewing ? { store.togglePreviewOnline() } : nil)
                .padding(.top, 76)
                .accessibilityLabel(Text("\(store.selected?.name ?? "AC"): \(state.summary). \(connection.text)"))

            VStack(spacing: 0) {
                header
                Spacer()
                temperature
                louvers
                    .padding(.top, 12)
            }
            .padding(16)
        }
        .frame(height: 356)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    /// Shown by the light on the AC, and named when hovering it.
    private var connection: (color: Color, text: String) {
        let preview = store.isPreviewing ? " · click to go \(state.isOnline ? "offline" : "online")" : ""
        if !state.isOnline { return (.red, "Offline\(preview)") }
        guard store.isLive || store.isPreviewing else { return (.yellow, "Connecting…") }
        return (.green, "Online\(preview)")
    }

    private var heroBackground: some View {
        HeroBackground(isOn: state.isOn)
    }

    private var header: some View {
        HStack(spacing: 10) {
            PowerButton(isOn: state.isOn) { store.send(.power(!state.isOn)) }
                .disabled(!store.canControl)
                .hoverHint(state.isOn ? "Turn off" : "Turn on", edge: .bottom)
            deviceMenu
            Spacer()
            if store.isPreviewing {
                Button("Preview") { store.isPreviewing = false }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.yellow))
                    .hoverHint("Not sending to the AC. Click to stop.", edge: .leading)
            }
        }
        .frame(height: 38)
    }

    @ViewBuilder
    private var deviceMenu: some View {
        let name = Text(store.selected?.name ?? "Air conditioner").font(.headline)
        if store.devices.count > 1 {
            Menu {
                ForEach(store.devices) { device in
                    Toggle(isOn: Binding(get: { device.id == store.selected?.id },
                                         set: { _ in store.selectedId = device.id })) {
                        Text(device.name)
                        if let room = device.room { Text(room) }
                    }
                }
            } label: {
                name
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
        } else {
            name
        }
    }

    /// The set temperature, large, with the room temperature under it.
    private var temperature: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if state.mode.usesSetpoint {
                        Text("\(state.setpoint, format: .number.precision(.fractionLength(state.setpoint == state.setpoint.rounded() ? 0 : 1)))°")
                    } else {
                        Text("Fan")
                    }
                }
                .font(.system(size: 60, weight: .ultraLight, design: .rounded))
                .contentTransition(.numericText(value: state.setpoint))
                .animation(.snappy, value: state.setpoint)
                .hoverHint(state.mode.usesSetpoint ? "Set temperature" : "Fan only: no set temperature", edge: .trailing)
                if let room = state.roomTemperatureText {
                    Label("Room \(room)", systemImage: "thermometer.medium")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.smooth, value: room)
                        // Above, not beside: to the right it would run into − and +.
                        .hoverHint("Room temperature, measured by the AC", edge: .top)
                }
            }
            // Its hints draw over the − / + buttons, not under them.
            .zIndex(1)
            Spacer()
            HStack(spacing: 8) {
                RoundButton(symbol: "minus") { step(-1) }
                    .disabled(state.setpoint <= ACState.temperatureRange.lowerBound)
                    .hoverHint("Cooler")
                RoundButton(symbol: "plus") { step(1) }
                    .disabled(state.setpoint >= ACState.temperatureRange.upperBound)
                    .hoverHint("Warmer")
            }
            .disabled(!store.canControl || !state.mode.usesSetpoint)
            .padding(.bottom, 6)
        }
        .opacity(state.isOn ? 1 : 0.6)
    }

    /// Up/down and left/right louvers: swing, or one of five fixed positions.
    private var louvers: some View {
        HStack(spacing: 8) {
            GlassSegments(values: Array(Louver.swing...Louver.positions.upperBound), selection: state.verticalLouver,
                          tint: tint, select: { store.send(.verticalLouver($0)) },
                          hint: { "Up/down: \(LouverLabel.vertical($0))" }, prominent: false) { position, _ in
                LouverGlyph(axis: .vertical, position: position)
            }
            GlassSegments(values: [Louver.swing] + Louver.horizontalLeftToRight, selection: state.horizontalLouver,
                          tint: tint, select: { store.send(.horizontalLouver($0)) },
                          hint: { "Left/right: \(LouverLabel.horizontal($0))" }, prominent: false) { position, _ in
                LouverGlyph(axis: .horizontal, position: position)
            }
        }
        .disabled(!store.canControl)
        .opacity(state.isOn ? 1 : 0.6)
    }

    // MARK: - Controls

    private var offlineBanner: some View {
        Label("\(store.selected?.name ?? "The AC") is offline. Check its power and Wi-Fi.", systemImage: "wifi.slash")
            .font(.caption)
            .frame(maxWidth: .infinity)
            .padding(8)
            .glassEffect(.regular.tint(.orange.opacity(0.6)), in: .rect(cornerRadius: 12))
    }

    private var modes: some View {
        LabeledBar(title: "Mode", value: state.mode.title) {
            GlassSegments(values: store.selectedCapabilities.modes, selection: state.mode, tint: state.mode.controlTint,
                          select: { store.send(.mode($0)) }, hint: { $0.title }) { mode, _ in
                Image(systemName: mode.symbol).font(.callout.weight(.semibold))
            }
        }
    }

    private var fanSpeeds: some View {
        // Named as in the MirAIe app.
        LabeledBar(title: "Fan", value: state.fan.rawValue.capitalized) {
            GlassSegments(values: FanSpeed.allCases, selection: state.fan, tint: tint,
                          select: { store.send(.fan($0)) }, hint: { $0.rawValue.capitalized }, prominent: false) { speed, _ in
                Image(systemName: speed.symbol).font(.callout.weight(.semibold))
            }
        }
    }

    /// Eco, Powerful, Converti7, nanoe X and Display as separate buttons: equal widths, each lit
    /// in its own colour while on, named on hover.
    private var features: some View {
        HStack(spacing: 8) {
            FeatureToggle(title: "Eco", symbol: "leaf", isOn: state.eco, tint: FeatureColor.eco) {
                store.send(.eco(!state.eco))
            }
            FeatureToggle(title: "Powerful", symbol: "bolt", isOn: state.powerful, tint: FeatureColor.powerful) {
                store.send(.powerful(!state.powerful))
            }
            if store.selectedCapabilities.converti {
                ConvertiToggle(level: state.converti ?? Converti.off) { store.send(.converti($0)) }
            }
            if store.selectedCapabilities.nanoe {
                let nanoe = state.nanoe ?? false
                FeatureToggle(title: "nanoe X air purifier", symbol: "aqi.medium", isOn: nanoe, tint: FeatureColor.nanoe) {
                    store.send(.nanoe(!nanoe))
                }
            }
            // The same colour as the AC's own display.
            FeatureToggle(title: "Display", symbol: "lightbulb", isOn: state.display, tint: .acDisplay) {
                store.send(.display(!state.display))
            }
        }
    }

    private func step(_ delta: Double) {
        store.send(.temperature(min(ACState.temperatureRange.upperBound,
                                    max(ACState.temperatureRange.lowerBound, state.setpoint + delta))))
    }

    private func send(_ commands: [ACCommand]) {
        switch commands.count {
        case 0: break
        case 1: store.send(commands[0])
        default: store.send(commands[0], commands[1])
        }
    }
}

/// Power as a round button: solid white while the AC runs (like an active Control Center
/// toggle), plain glass while it's off.
private struct PowerButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "power")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 32)
                .foregroundStyle(isOn ? Color.black : .primary)
                .background(Circle().fill(.white).opacity(isOn ? 1 : 0))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isOn ? "Turn off" : "Turn on")
        .animation(.snappy, value: isOn)
    }
}

/// Each feature's colour while on: deep enough for a white icon to read clearly (about the
/// depth of the display blue), and distinct from one another.
private enum FeatureColor {
    static let eco = Color(red: 0.11, green: 0.5, blue: 0.27)
    static let powerful = Color(red: 0.8, green: 0.34, blue: 0.06)
    static let converti = Color(red: 0.0, green: 0.45, blue: 0.5)
    static let nanoe = Color(red: 0.42, green: 0.32, blue: 0.82)
}

/// One feature button: an icon, filled in the feature's colour while on.
private struct FeatureToggle: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FeatureIcon(symbol: symbol, isOn: isOn, tint: tint)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .capsule)
        .hoverHint("\(title): \(isOn ? "on" : "off")")
    }
}

/// The Converti7 button; opens a menu of cooling levels.
private struct ConvertiToggle: View {
    let level: Int
    let select: (Int) -> Void

    var body: some View {
        let isOn = level != Converti.off
        Menu {
            Picker("Converti7", selection: Binding(get: { level }, set: select)) {
                Text("Off").tag(Converti.off)
                ForEach(Converti.levels.reversed(), id: \.self) { Text("\($0)%").tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            FeatureIcon(symbol: "dial.medium", isOn: isOn, tint: FeatureColor.converti)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .glassEffect(.regular, in: .capsule)
        .hoverHint(isOn ? "Converti7: \(level)%" : "Converti7: off")
    }
}

private struct FeatureIcon: View {
    let symbol: String
    let isOn: Bool
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .symbolVariant(isOn ? .fill : .none)
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 34)
            .foregroundStyle(isOn ? Color.white : .secondary)
            .background(Capsule().fill(tint.gradient).opacity(isOn ? 1 : 0))
            .contentShape(.capsule)
            .animation(.easeOut(duration: 0.15), value: isOn)
    }
}
