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
                Group {
                    fanSpeeds
                    modes
                    features
                    schedules
                }
                .disabled(!store.canControl)
                .opacity(controlOpacity(off: 0.55))
                UpdateBanner(updates: UpdateChecker.shared)
            }
            .padding(16)
            .animation(.snappy, value: UpdateChecker.shared.state)
        }
        .animation(.snappy, value: state.isOnline)
    }

    /// Controls fade a little while the AC is off, and a lot while it's offline.
    private func controlOpacity(off: Double) -> Double {
        !state.isOnline ? 0.35 : state.isOn ? 1 : off
    }

    /// The AC as drawn. Offline, nothing it last reported can be trusted, so it's drawn idle:
    /// no air and a dark display, with only the red light on.
    private var drawnState: ACState {
        var drawn = state
        if !state.isOnline { drawn.isOn = false }
        return drawn
    }

    // MARK: - Hero

    /// The AC edge to edge with its air, the room temperature over it and the louver controls
    /// along the bottom.
    private var hero: some View {
        ZStack(alignment: .top) {
            heroBackground
            ACUnitView(state: drawnState, statusLight: connection.color, statusText: connection.text,
                       onStatusLightTap: store.isPreviewing ? { store.togglePreviewOnline() } : nil)
                .padding(.top, 76)
                .accessibilityLabel(Text("\(store.selected?.name ?? "AC"): \(state.summary). \(connection.text)"))
            // Offline, the AC blows no air: the message takes its place under the unit, so nothing
            // moves and it's clear it's the AC that can't be reached.
            if !state.isOnline {
                offlineNotice
                    .padding(.top, 152)
                    .transition(.opacity)
            } else if !scheduleLabels.isEmpty {
                schedule
                    .padding(.top, 156)
                    .transition(.opacity)
            }

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
        HeroBackground(isOn: drawnState.isOn)
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
                        .hoverHint("Room temperature, measured by the AC", edge: .top, anchor: .leading)
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
        .opacity(controlOpacity(off: 0.6))
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
        .opacity(controlOpacity(off: 0.6))
    }

    /// What the AC will do by itself: its timers and the sleep profile it's running.
    private var scheduleLabels: [(symbol: String, text: String)] {
        var labels: [(String, String)] = []
        if state.sleepProfile != nil {
            // A profile started in the MirAIe app: its name and length aren't sent to the AC, so
            // which hour it's on means little.
            if let known = store.runningSleepProfile {
                let hour = state.sleepHour.map { " · hour \(min($0 + 1, known.temperatures.count)) of \(known.temperatures.count)" }
                labels.append(("bed.double", known.name + (hour ?? "")))
            } else {
                labels.append(("bed.double", "Sleep profile on"))
            }
        }
        if let off = state.offTimer, off > Date() { labels.append(("timer", "Off at \(Self.time(off))")) }
        if let on = state.onTimer, on > Date() { labels.append(("timer", "On at \(Self.time(on))")) }
        return labels
    }

    private var schedule: some View {
        HStack(spacing: 6) {
            ForEach(scheduleLabels, id: \.text) { label in
                Label(label.text, systemImage: label.symbol)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: scheduleLabels.map(\.text))
    }

    /// "9:20 PM", or "Tue 7:00 AM" when it's not in the next day.
    private static func time(_ date: Date) -> String {
        date.timeIntervalSinceNow < 20 * 3600
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    // MARK: - Controls

    private var offlineNotice: some View {
        // The icon sits beside both lines, centred on them; the block as a whole is centred.
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.25))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(store.selected?.name ?? "The AC") is offline")
                    .font(.headline)
                Text("Check its power and Wi-Fi.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
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
            // A lit bulb: warm incandescent amber, with a dark icon so it reads on the light fill.
            FeatureToggle(title: "Display", symbol: "lightbulb", isOn: state.display,
                          tint: FeatureColor.bulb, icon: FeatureColor.bulbIcon) {
                store.send(.display(!state.display))
            }
        }
    }

    /// Timer and Sleep get a row of their own, named and showing what's set: few apps for these
    /// ACs offer them.
    private var schedules: some View {
        HStack(spacing: 8) {
            ScheduleButton(title: "Timer", detail: timerDetail, symbol: "timer",
                           isOn: state.offTimer != nil || state.onTimer != nil, tint: FeatureColor.timer) {
                TimerPopover(state: state).environment(store)
            }
            ScheduleButton(title: "Sleep", detail: sleepDetail, symbol: "bed.double",
                           isOn: state.sleepProfile != nil, tint: FeatureColor.sleep) {
                SleepPopover().environment(store)
            }
        }
    }

    /// The sooner timer; both are listed under the AC.
    private var timerDetail: String {
        let timers = [state.offTimer.map { ("Off", $0) }, state.onTimer.map { ("On", $0) }].compactMap(\.self)
        guard let next = timers.min(by: { $0.1 < $1.1 }) else { return "Turn on or off later" }
        return "\(next.0) at \(Self.time(next.1))"
    }

    private var sleepDetail: String {
        guard state.sleepProfile != nil else { return "Hourly temperatures" }
        return store.runningSleepProfile?.name ?? "Profile on"
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

/// Each feature's colour while on, distinct from one another. Most are deep enough for a white
/// icon; the bulb is a light, warm amber and takes a dark icon instead.
private enum FeatureColor {
    static let eco = Color(red: 0.11, green: 0.5, blue: 0.27)
    static let powerful = Color(red: 0.8, green: 0.34, blue: 0.06)
    static let converti = Color(red: 0.0, green: 0.45, blue: 0.5)
    static let nanoe = Color(red: 0.42, green: 0.32, blue: 0.82)
    static let bulb = Color(red: 1.0, green: 0.74, blue: 0.36)
    static let bulbIcon = Color(red: 0.3, green: 0.17, blue: 0.0)
    static let timer = Color(red: 0.16, green: 0.4, blue: 0.78)
    static let sleep = Color(red: 0.3, green: 0.26, blue: 0.62)
}

/// A wide button with its name and what's set, opening a popover. While something is set, its
/// icon sits in a disc of the feature's colour and the button takes a tint of it.
private struct ScheduleButton<Content: View>: View {
    let title: String
    let detail: String
    let symbol: String
    let isOn: Bool
    let tint: Color
    @ViewBuilder let content: () -> Content
    @State private var isPresented = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .symbolVariant(isOn ? .fill : .none)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isOn ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isOn ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.quaternary)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(tint.opacity(isOn && isEnabled ? 0.18 : 0)))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(.snappy, value: isOn)
        .animation(.snappy, value: detail)
        .popover(isPresented: $isPresented, arrowEdge: .bottom, content: content)
    }
}



/// One feature button: an icon, filled in the feature's colour while on.
private struct FeatureToggle: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let tint: Color
    var icon: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FeatureIcon(symbol: symbol, isOn: isOn, tint: tint, icon: icon)
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
            Picker("Converti7", selection: Binding(get: { level }, set: { select($0) })) {
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
    /// The icon's colour while on.
    var icon: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: symbol)
            .symbolVariant(isOn ? .fill : .none)
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 34)
            // Disabled, the panel dims the fill, so a dark icon (the bulb's) would vanish into it.
            .foregroundStyle(isOn ? (isEnabled ? icon : Color.white) : .secondary)
            .background(Capsule().fill(tint.gradient).opacity(isOn ? 1 : 0))
            .contentShape(.capsule)
            .animation(.easeOut(duration: 0.15), value: isOn)
    }
}
