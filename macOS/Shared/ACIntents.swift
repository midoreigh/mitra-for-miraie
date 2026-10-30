import AppIntents
import Foundation
import WidgetKit
import MitraKit
import MitraUI

/// Runs an intent's commands against the chosen AC (or the default one) and tells the app
/// and widgets about the result.
enum ACIntentRunner {
    static func run(_ entity: ACEntity?,
                    commands: (ACState) throws -> [ACCommand]) async throws -> (Device, ACState) {
        let service = MirAIeService.shared
        let device = try await service.device(id: entity?.id)
        let current = try await service.refreshState(of: device)
        guard current.isOnline else { throw MitraError.deviceOffline(device.name) }
        let state = try await service.send(try commands(current), to: device)
        didChange()
        return (device, state)
    }

    static func didChange() {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        DistributedNotificationCenter.default().postNotificationName(
            SharedContainer.didChangeNotification, object: nil, userInfo: nil, deliverImmediately: true)
    }
}

// MARK: - Power

struct TurnOnACIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn On Air Conditioner"
    static let description = IntentDescription("Turns on an air conditioner.")

    @Parameter(title: "Air Conditioner") var device: ACEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (device, state) = try await ACIntentRunner.run(device) { _ in [.power(true)] }
        return .result(dialog: "\(device.name) is on. \(state.summary).")
    }
}

struct TurnOffACIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Off Air Conditioner"
    static let description = IntentDescription("Turns off an air conditioner.")

    @Parameter(title: "Air Conditioner") var device: ACEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (device, _) = try await ACIntentRunner.run(device) { _ in [.power(false)] }
        return .result(dialog: "\(device.name) is off.")
    }
}

/// Flips the power; used by the widgets' power button.
struct ToggleACPowerIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Air Conditioner"
    static let description = IntentDescription("Turns an air conditioner on if it's off, or off if it's on.")

    @Parameter(title: "Air Conditioner") var device: ACEntity?

    init() {}
    init(device: ACEntity?) { self.device = device }

    func perform() async throws -> some IntentResult {
        _ = try await ACIntentRunner.run(device) { [.power(!$0.isOn)] }
        return .result()
    }
}

/// Sets the power to a given value; drives the Control Center toggle.
struct SetACPowerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set Air Conditioner Power"

    @Parameter(title: "Air Conditioner") var device: ACEntity?
    @Parameter(title: "On") var value: Bool

    func perform() async throws -> some IntentResult {
        _ = try await ACIntentRunner.run(device) { _ in [.power(value)] }
        return .result()
    }
}

// MARK: - Temperature

struct SetACTemperatureIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Air Conditioner Temperature"
    static let description = IntentDescription("Sets the temperature, turning the air conditioner on if needed.")

    @Parameter(title: "Temperature", description: "In °C, from 16 to 30.",
               inclusiveRange: (16, 30), requestValueDialog: "What temperature?")
    var temperature: Int
    @Parameter(title: "Air Conditioner") var device: ACEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$device) to \(\.$temperature)°")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (device, state) = try await ACIntentRunner.run(device) { current in
            current.isOn ? [.temperature(Double(temperature))] : [.power(true), .temperature(Double(temperature))]
        }
        return .result(dialog: "\(device.name) is set to \(ACState.format(state.setpoint)).")
    }
}

struct AdjustACTemperatureIntent: AppIntent {
    static let title: LocalizedStringResource = "Make Cooler or Warmer"
    static let description = IntentDescription("Moves the temperature down or up by one degree or more.")

    @Parameter(title: "Direction") var direction: TemperatureDirection
    @Parameter(title: "Degrees", default: 1, inclusiveRange: (1, 14)) var degrees: Int
    @Parameter(title: "Air Conditioner") var device: ACEntity?

    init() {}
    init(direction: TemperatureDirection, device: ACEntity?) {
        self.direction = direction
        self.degrees = 1
        self.device = device
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Make \(\.$device) \(\.$direction) by \(\.$degrees)°")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let delta = Double(direction == .cooler ? -degrees : degrees)
        let (device, state) = try await ACIntentRunner.run(device) { current in
            let range = ACState.temperatureRange
            let target = min(range.upperBound, max(range.lowerBound, current.setpoint + delta))
            return current.isOn ? [.temperature(target)] : [.power(true), .temperature(target)]
        }
        return .result(dialog: "\(device.name) is now set to \(ACState.format(state.setpoint)).")
    }
}

// MARK: - Mode, fan and airflow

struct SetACModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Air Conditioner Mode"
    static let description = IntentDescription("Switches between Cool, Auto, Dry, Fan and Heat.")

    @Parameter(title: "Mode") var mode: ACModeOption
    @Parameter(title: "Air Conditioner") var device: ACEntity?

    init() {}
    init(mode: ACModeOption, device: ACEntity?) {
        self.mode = mode
        self.device = device
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$device) to \(\.$mode)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (device, state) = try await ACIntentRunner.run(device) { current in
            current.isOn ? [.mode(mode.mode)] : [.power(true), .mode(mode.mode)]
        }
        return .result(dialog: "\(device.name): \(state.summary).")
    }
}

struct SetACFanSpeedIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Air Conditioner Fan Speed"

    @Parameter(title: "Fan Speed") var speed: FanSpeedOption
    @Parameter(title: "Air Conditioner") var device: ACEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$device) fan to \(\.$speed)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (device, _) = try await ACIntentRunner.run(device) { _ in [.fan(speed.speed)] }
        return .result(dialog: "\(device.name) fan is on \(speed.speed.rawValue).")
    }
}

struct SetACVerticalAirflowIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Up/Down Airflow"
    static let description = IntentDescription("Points the air up or down, or sweeps it.")

    @Parameter(title: "Direction") var direction: VerticalAirflowOption
    @Parameter(title: "Air Conditioner") var device: ACEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$device) up/down airflow to \(\.$direction)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (device, _) = try await ACIntentRunner.run(device) { _ in [.verticalLouver(direction.rawValue)] }
        return .result(dialog: "\(device.name) up/down airflow: \(LouverLabel.vertical(direction.rawValue)).")
    }
}

struct SetACHorizontalAirflowIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Left/Right Airflow"
    static let description = IntentDescription("Points the air left or right, or sweeps it.")

    @Parameter(title: "Direction") var direction: HorizontalAirflowOption
    @Parameter(title: "Air Conditioner") var device: ACEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$device) left/right airflow to \(\.$direction)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let position = direction == .swing ? Louver.swing : Louver.horizontalLeftToRight[direction.rawValue - 1]
        let (device, _) = try await ACIntentRunner.run(device) { _ in [.horizontalLouver(position)] }
        return .result(dialog: "\(device.name) left/right airflow: \(LouverLabel.horizontal(position)).")
    }
}

// MARK: - Status

struct GetACStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Air Conditioner Status"
    static let description = IntentDescription("Tells you whether the air conditioner is on, its setting and the room temperature.")

    @Parameter(title: "Air Conditioner") var device: ACEntity?

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let service = MirAIeService.shared
        let device = try await service.device(id: device?.id)
        let state = try await service.refreshState(of: device)
        var sentence = "\(device.name): \(state.summary)."
        if let room = state.roomTemperatureText { sentence += " The room is \(room)." }
        return .result(value: sentence, dialog: "\(sentence)")
    }
}
