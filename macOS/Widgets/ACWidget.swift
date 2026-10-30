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
            return ACEntry(date: .now, device: ACEntity(device), state: state)
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

struct ACWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ACEntry

    private var state: ACState { entry.state }
    private var tint: Color { state.mode.tint }

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
            ZStack {
                Color(white: 0.08)
                LinearGradient(colors: [tint.opacity(state.isOn ? 0.55 : 0.12), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: Families

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                title
                Spacer()
                powerButton(size: 30)
            }
            Spacer(minLength: 0)
            setpoint(size: 40)
            status
        }
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                title
                Spacer(minLength: 0)
                setpoint(size: 44)
                status
            }
            VStack(spacing: 8) {
                ACUnitView(state: state, animated: false)
                    .frame(height: 70)
                HStack(spacing: 8) {
                    stepButton(.cooler)
                    powerButton(size: 34)
                    stepButton(.warmer)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                title
                Spacer()
                powerButton(size: 36)
            }
            ACUnitView(state: state, animated: false)
                .frame(height: 120)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    setpoint(size: 50)
                    status
                }
                Spacer()
                stepButton(.cooler)
                stepButton(.warmer)
            }
            HStack(spacing: 6) {
                ForEach(ACMode.allCases) { mode in
                    Button(intent: SetACModeIntent(mode: ACModeOption(rawValue: mode.rawValue)!, device: entry.device)) {
                        VStack(spacing: 3) {
                            Image(systemName: mode.symbol)
                            Text(mode.title).font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(mode == state.mode && state.isOn ? mode.tint.opacity(0.85) : .white.opacity(0.1),
                                    in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Pieces

    private var title: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.device?.name ?? "Air Conditioner")
                .font(.headline)
                .lineLimit(1)
            if let room = state.roomTemperatureText {
                Label("Room \(room)", systemImage: "thermometer.medium")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func setpoint(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(ACState.format(state.setpoint).dropLast())
                .font(.system(size: size, weight: .light, design: .rounded))
                .contentTransition(.numericText())
            Text("°C").font(.caption.weight(.semibold)).foregroundStyle(tint)
        }
        .opacity(state.isOn ? 1 : 0.5)
        .widgetAccentable()
    }

    private var status: some View {
        Label(state.summary, systemImage: state.isOn ? state.mode.symbol : "power")
            .font(.caption2.weight(.medium))
            .foregroundStyle(state.isOn ? tint : .secondary)
            .lineLimit(1)
    }

    private func powerButton(size: CGFloat) -> some View {
        Button(intent: ToggleACPowerIntent(device: entry.device)) {
            Image(systemName: "power")
                .font(.system(size: size * 0.42, weight: .bold))
                .frame(width: size, height: size)
                .background(state.isOn ? tint : .white.opacity(0.15), in: .circle)
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .widgetAccentable()
    }

    private func stepButton(_ direction: TemperatureDirection) -> some View {
        Button(intent: AdjustACTemperatureIntent(direction: direction, device: entry.device)) {
            Image(systemName: direction == .cooler ? "minus" : "plus")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.15), in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(!state.mode.usesSetpoint)
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
