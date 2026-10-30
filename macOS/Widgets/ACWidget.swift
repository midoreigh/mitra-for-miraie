import AppIntents
import SwiftUI
import WidgetKit
import MitraKit
import MitraUI

struct SelectACIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Air Conditioner"
    static let description = IntentDescription("Pick which air conditioner the widget shows.")

    @Parameter(title: "Air Conditioner") var device: ACEntity?
}

struct ACEntry: TimelineEntry {
    let date: Date
    let device: ACEntity?
    let state: ACState
    var capabilities = ACCapabilities()
    /// Why there's nothing to show, e.g. not signed in.
    var problem: String?

    static let placeholder: ACEntry = {
        var state = ACState()
        state.isOn = true
        state.roomTemperature = 27.5
        return ACEntry(date: .now, device: nil, state: state)
    }()
}

struct ACTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ACEntry { .placeholder }

    func snapshot(for configuration: SelectACIntent, in context: Context) async -> ACEntry {
        context.isPreview && SharedStore.shared.devices.isEmpty ? .placeholder : await entry(for: configuration, refresh: false)
    }

    func timeline(for configuration: SelectACIntent, in context: Context) async -> Timeline<ACEntry> {
        let entry = await entry(for: configuration, refresh: true)
        // The app reloads widgets whenever the AC changes; this is a fallback for when it isn't running.
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }

    private func entry(for configuration: SelectACIntent, refresh: Bool) async -> ACEntry {
        let service = MirAIeService.shared
        do {
            let device = try await service.device(id: configuration.device?.id)
            var state = SharedStore.shared.state(for: device.id) ?? ACState()
            if refresh, let fresh = try? await service.currentState(of: device, maxAge: 60) { state = fresh }
            return ACEntry(date: .now, device: ACEntity(device), state: state,
                           capabilities: SharedStore.shared.capabilities(for: device.id))
        } catch {
            return ACEntry(date: .now, device: nil, state: ACState(), problem: error.localizedDescription)
        }
    }
}

struct ACWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.midoreigh.mitra.ac", intent: SelectACIntent.self,
                               provider: ACTimelineProvider()) { entry in
            ACWidgetView(entry: entry)
        }
        .configurationDisplayName("Air Conditioner")
        .description("See and control your air conditioner.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

/// The panel in miniature: the graphite night sky, the drawn unit with its light, the set
/// temperature large with the room temperature under it, and the same round buttons and bars.
/// Widgets can't run continuous animations, so the air is shown mid-stream; changes animate
/// when a new entry arrives, and tapped controls show as pending until the AC confirms.
struct ACWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ACEntry

    private var state: ACState { entry.state }

    var body: some View {
        Group {
            if let problem = entry.problem {
                VStack(spacing: 8) {
                    Image(systemName: "air.conditioner.horizontal").font(.title)
                    Text(problem).font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
            } else {
                switch family {
                case .systemSmall: small
                case .systemLarge: large
                default: medium
                }
            }
        }
        .containerBackground(for: .widget) {
            GraphiteBackdrop(isOn: state.isOn, animated: false)
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: Families

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(power: 26)
            unit(height: 44)
                .padding(.top, 10)
            Spacer(minLength: 0)
            setpoint(size: 36)
            room
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                header(power: 28)
                Spacer(minLength: 0)
                setpoint(size: 46)
                room
            }
            VStack(spacing: 12) {
                unit(height: 70)
                HStack(spacing: 10) {
                    stepButton(.cooler)
                    stepButton(.warmer)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(power: 30)
            unit(height: 112)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    setpoint(size: 50)
                    room
                }
                Spacer()
                stepButton(.cooler)
                stepButton(.warmer)
            }
            fanRow
            modeRow
        }
    }

    // MARK: Pieces

    private func header(power size: CGFloat) -> some View {
        HStack(spacing: 8) {
            powerButton(size: size)
            Text(entry.device?.name ?? "Air Conditioner")
                .font(.headline)
                .lineLimit(1)
        }
    }

    private func unit(height: CGFloat) -> some View {
        ACUnitView(state: state, animated: false, statusLight: state.isOnline ? .green : .red)
            .frame(height: height)
    }

    private func setpoint(size: CGFloat) -> some View {
        Group {
            if state.mode.usesSetpoint {
                Text("\(state.setpoint, format: .number.precision(.fractionLength(state.setpoint == state.setpoint.rounded() ? 0 : 1)))°")
            } else {
                Text("Fan")
            }
        }
        .font(.system(size: size, weight: .ultraLight, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(.numericText(value: state.setpoint))
        .opacity(state.isOn ? 1 : 0.6)
        .invalidatableContent()
    }

    @ViewBuilder
    private var room: some View {
        if let room = state.roomTemperatureText {
            Label("Room \(room)", systemImage: "thermometer.medium")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
    }

    /// Solid white while the AC runs, like the panel's power button.
    private func powerButton(size: CGFloat) -> some View {
        Button(intent: ToggleACPowerIntent(device: entry.device)) {
            Image(systemName: "power")
                .font(.system(size: size * 0.42, weight: .bold))
                .frame(width: size, height: size)
                .foregroundStyle(state.isOn ? Color.black : .white)
                .background(Circle().fill(state.isOn ? Color.white : .white.opacity(0.15)))
                .invalidatableContent()
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ direction: TemperatureDirection) -> some View {
        Button(intent: AdjustACTemperatureIntent(direction: direction, device: entry.device)) {
            Image(systemName: direction == .cooler ? "minus" : "plus")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 32, height: 32)
                .background(Circle().fill(.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .disabled(!state.mode.usesSetpoint)
    }

    private var fanRow: some View {
        WidgetBar(title: "Fan", value: state.fan.rawValue.capitalized) {
            ForEach(FanSpeed.allCases) { speed in
                let selected = speed == state.fan
                Button(intent: SetACFanSpeedIntent(speed: FanSpeedOption(rawValue: speed.rawValue)!, device: entry.device)) {
                    WidgetSegment(symbol: speed.symbol, isSelected: selected, fill: .white, selectedIcon: .black)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var modeRow: some View {
        WidgetBar(title: "Mode", value: state.mode.title) {
            ForEach(entry.capabilities.modes) { mode in
                let selected = mode == state.mode
                Button(intent: SetACModeIntent(mode: ACModeOption(rawValue: mode.rawValue)!, device: entry.device)) {
                    WidgetSegment(symbol: mode.symbol, isSelected: selected, fill: mode.controlTint, selectedIcon: .white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A row of options with its name and current value on the left, as in the panel.
private struct WidgetBar<Segments: View>: View {
    let title: String
    let value: String
    @ViewBuilder let segments: Segments

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.semibold)).invalidatableContent()
            }
            .lineLimit(1)
            .frame(width: 52, alignment: .leading)
            HStack(spacing: 2) { segments }
                .padding(3)
                .background(Capsule().fill(.white.opacity(0.08)))
        }
    }
}

private struct WidgetSegment: View {
    let symbol: String
    let isSelected: Bool
    let fill: Color
    let selectedIcon: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 28)
            .foregroundStyle(isSelected ? selectedIcon : .secondary)
            .background { if isSelected { Capsule().fill(fill.gradient) } }
            .contentShape(.capsule)
            .invalidatableContent()
    }
}

// MARK: - Control Center

struct ACPowerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.midoreigh.mitra.power", provider: Provider()) { isOn in
            ControlWidgetToggle("Air Conditioner", isOn: isOn, action: SetACPowerIntent()) { on in
                Label(on ? "On" : "Off",
                      systemImage: on ? "air.conditioner.horizontal.fill" : "air.conditioner.horizontal")
            }
            .tint(.blue)
        }
        .displayName("Air Conditioner")
        .description("Turns your default air conditioner on or off.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            let service = MirAIeService.shared
            let device = try await service.device(id: nil)
            return try await service.currentState(of: device, maxAge: 30).isOn
        }
    }
}

#Preview(as: .systemMedium) {
    ACWidget()
} timeline: {
    ACEntry.placeholder
}
