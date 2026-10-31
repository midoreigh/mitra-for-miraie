import Foundation

public enum ACMode: String, CaseIterable, Codable, Identifiable, Sendable {
    // Auto first, as on the fan speeds.
    case auto, cool, dry, fan, heat

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .cool: "snowflake"
        case .auto: "sparkles"
        case .dry: "drop.fill"
        case .fan: "fan.fill"
        case .heat: "sun.max.fill"
        }
    }
    /// Fan-only mode has no temperature setpoint.
    public var usesSetpoint: Bool { self != .fan }
}

public enum FanSpeed: String, CaseIterable, Codable, Identifiable, Sendable {
    case auto, quiet, low, medium, high

    public var id: String { rawValue }
    public var title: String { self == .medium ? "Med" : rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .auto: "fan.badge.automatic"
        case .quiet: "moon.zzz"
        case .low: "wind"
        case .medium: "wind.circle"
        case .high: "tornado"
        }
    }
    /// 0 for auto, otherwise 1 (quiet) to 4 (high); drives the airflow animation speed.
    public var level: Int {
        switch self {
        case .auto: 0
        case .quiet: 1
        case .low: 2
        case .medium: 3
        case .high: 4
        }
    }
}

/// Panasonic Converti7: run the AC at a share of its full cooling capacity, in percent, to
/// save power or cool harder. 0 is off (normal operation).
public enum Converti {
    public static let off = 0
    public static let levels = [40, 55, 70, 80, 90, 100, 110]
}

/// Louver positions. MirAIe uses 0 for continuous swing and 1–5 for fixed positions.
/// Vertically 1 is nearly level and 5 points down. Horizontally they're out of order (seen on
/// a Panasonic unit): 1 points straight ahead, 2 far left, 3 left, 4 right and 5 far right.
public enum Louver {
    public static let swing = 0
    public static let positions = 1...5

    /// MirAIe's left/right positions, from far left to far right.
    public static let horizontalLeftToRight = [2, 3, 1, 4, 5]

    /// Where a MirAIe left/right position sits from the left: 1 (far left) to 5 (far right).
    public static func horizontalSlot(_ position: Int) -> Int {
        (horizontalLeftToRight.firstIndex(of: position) ?? 2) + 1
    }
}

/// What an AC can do. MirAIe doesn't say, so this starts from what most MirAIe units have
/// (no heating, no nanoe™ X) and learns more from what the AC itself reports. The user can
/// also switch features on in Settings.
public struct ACCapabilities: Codable, Hashable, Sendable {
    public var heat = false
    public var nanoe = false
    /// Panasonic's Converti7 cooling levels; most MirAIe-connected Panasonic units have them.
    public var converti = true

    public init(heat: Bool = false, nanoe: Bool = false, converti: Bool = true) {
        self.heat = heat
        self.nanoe = nanoe
        self.converti = converti
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        heat = try container.decodeIfPresent(Bool.self, forKey: .heat) ?? false
        nanoe = try container.decodeIfPresent(Bool.self, forKey: .nanoe) ?? false
        converti = try container.decodeIfPresent(Bool.self, forKey: .converti) ?? true
    }

    public var modes: [ACMode] { ACMode.allCases.filter { $0 != .heat || heat } }

    /// Adds anything a state reported by the AC shows it can do.
    public func learning(from state: ACState) -> ACCapabilities {
        var learned = self
        if state.mode == .heat { learned.heat = true }
        if state.nanoe == true { learned.nanoe = true }
        return learned
    }
}

/// One air conditioner's state, decoded from MirAIe status fields.
public struct ACState: Codable, Hashable, Sendable {
    public static let temperatureRange = 16.0...30.0

    public var isOn = false
    public var setpoint = 24.0
    public var mode = ACMode.cool
    public var fan = FanSpeed.auto
    public var verticalLouver = Louver.swing
    public var horizontalLouver = Louver.swing
    public var eco = false
    public var powerful = false
    /// The Converti7 level in percent; 0 or nil when off.
    public var converti: Int?
    public var display = true
    /// nil when the AC doesn't report its nanoe™ X ionizer. Many units report it as off even
    /// without one, so `ACCapabilities.nanoe` decides whether to offer it.
    public var nanoe: Bool?
    public var roomTemperature: Double?
    public var isOnline = true
    /// Signal strength the AC reports for its own Wi-Fi connection, in dBm.
    public var wifiSignal: Int?
    public var firmware: String?
    /// When the AC will turn itself off or on, if a timer is set.
    public var offTimer: Date?
    public var onTimer: Date?
    /// The ID of the sleep profile the AC is running, and which hour of it (from 0).
    public var sleepProfile: String?
    public var sleepHour: Int?
    public var updatedAt = Date.distantPast

    public init() {}

    public init(fields: [String: Any]) {
        apply(fields)
    }

    /// Merges a full or partial MirAIe status message.
    public mutating func apply(_ fields: [String: Any]) {
        if let value = Self.string(fields["V"]), !value.isEmpty { firmware = value }
        if let value = Self.string(fields["ps"]) { isOn = value == "on" }
        if let value = Self.double(fields["actmp"]) { setpoint = value }
        if let value = Self.string(fields["acmd"]).flatMap(ACMode.init) { mode = value }
        if let value = Self.string(fields["acfs"]).flatMap(FanSpeed.init) { fan = value }
        if let value = Self.double(fields["acvs"]) { verticalLouver = Int(value) }
        if let value = Self.double(fields["achs"]) { horizontalLouver = Int(value) }
        if let value = Self.string(fields["acem"]) { eco = value == "on" }
        if let value = Self.string(fields["acpm"]) { powerful = value == "on" }
        if let value = Self.double(fields["cnv"]) { converti = Int(value) }
        if let value = Self.string(fields["acdc"]) { display = value != "off" }
        if let value = Self.string(fields["acng"]) { nanoe = value == "on" }
        if let value = Self.string(fields["onlineStatus"]) { isOnline = value == "true" }
        if let value = Self.double(fields["rssi"]) { wifiSignal = Int(value) }
        if let value = Self.string(fields["rmtmp"]), let room = Self.roomTemperature(value, firmware: firmware) {
            roomTemperature = room
        }
        // Timers come back as the time they go off; -1 when not set.
        if let timers = fields["actm"] as? [Any], timers.count == 2 {
            (offTimer, onTimer) = (Self.timer(timers[0]), Self.timer(timers[1]))
        }
        if let value = Self.string(fields["acsp"]) {
            sleepProfile = value == "none" || value == "off" || value.isEmpty ? nil : value
            if sleepProfile == nil { sleepHour = nil }
        }
        if let value = Self.double(fields["sleep_indx"]) { sleepHour = Int(value) }
        updatedAt = Date()
    }

    /// Applies a command locally, for an optimistic update before the AC confirms it.
    public mutating func apply(_ command: ACCommand) {
        switch command {
        case .timers(let off, let on):
            offTimer = off
            onTimer = on
            updatedAt = Date()
        case .startSleep(let profile):
            sleepProfile = profile.id
            sleepHour = 0
            if let first = profile.schedule(from: setpoint).first { setpoint = first }
            updatedAt = Date()
        case .stopSleep:
            sleepProfile = nil
            sleepHour = nil
            updatedAt = Date()
        default:
            apply(command.fields)
        }
    }

    private static func timer(_ value: Any) -> Date? {
        guard let seconds = double(value), seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// Room temperature in °C. Firmware 3.02+ packs sub-degree precision as
    /// "<fraction × 256>.<degrees>", e.g. "43.28" is 28 + 43/256 ≈ 28.17 °C.
    static func roomTemperature(_ value: String, firmware: String?) -> Double? {
        let version = (firmware ?? "").split(separator: ".").compactMap { Int($0.filter(\.isNumber)) }
        let packed = version.count >= 2 && (version[0], version[1]) >= (3, 2)
        let parts = value.split(separator: ".")
        // Some 3.02 units still send a plain reading ("26.5"); unpacking that gives 5.1°, so only
        // trust the packed form when it comes out as a believable room temperature.
        if packed, parts.count == 2, let fraction = Double(parts[0]), let degrees = Double(parts[1]),
           fraction < 256, (10...50).contains(degrees) {
            return degrees + fraction / 256
        }
        return Double(value)
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String: string
        case let number as NSNumber: number.stringValue
        default: nil
        }
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: number.doubleValue
        case let string as String: Double(string)
        default: nil
        }
    }
}

/// A control command, published as JSON to the AC's `<topic>/control` MQTT topic.
public enum ACCommand: Hashable, Sendable {
    case power(Bool)
    case temperature(Double)
    case mode(ACMode)
    case fan(FanSpeed)
    case verticalLouver(Int)
    case horizontalLouver(Int)
    case eco(Bool)
    case powerful(Bool)
    case display(Bool)
    case nanoe(Bool)
    case converti(Int)
    /// Sets both timers at once: the AC replaces both with every command, so the one not being
    /// changed has to be sent again. nil clears a timer.
    case timers(off: Date?, on: Date?)
    case startSleep(SleepProfile)
    /// Stops the running profile, by its ID; `temperatures` as last sent, if known.
    case stopSleep(id: String, temperatures: [String])

    /// The status fields this command changes.
    public var fields: [String: Any] {
        switch self {
        case .power(let on): ["ps": on ? "on" : "off"]
        case .temperature(let value): ["actmp": Self.format(value)]
        case .mode(let mode): ["acmd": mode.rawValue]
        case .fan(let speed): ["acfs": speed.rawValue]
        case .verticalLouver(let position): ["acvs": Self.louver(position)]
        case .horizontalLouver(let position): ["achs": Self.louver(position)]
        // Eco and Powerful are mutually exclusive; the MirAIe app sets 26 °C when enabling Eco.
        case .eco(true): ["acem": "on", "acpm": "off", "actmp": "26"]
        case .eco(false): ["acem": "off"]
        case .powerful(true): ["acpm": "on", "acem": "off"]
        case .powerful(false): ["acpm": "off"]
        case .display(let on): ["acdc": on ? "on" : "off"]
        case .nanoe(let on): ["acng": on ? "on" : "off"]
        // Converti replaces Eco and Powerful, as in the MirAIe app.
        case .converti(Converti.off): ["cnv": Converti.off]
        case .converti(let level): ["cnv": level, "acem": "off", "acpm": "off"]
        // Sent as seconds from now, which the AC adds to its own clock.
        case .timers(let off, let on): ["actm": [Self.seconds(until: off), Self.seconds(until: on)]]
        case .startSleep(let profile): ["acsp": "on", "pid": profile.id, "temps": profile.wireTemperatures]
        case .stopSleep(let id, let temperatures): ["acsp": "off", "pid": id, "temps": temperatures]
        }
    }

    /// The MirAIe app's command kind for each; the AC seems to accept 1 for everything else.
    var kind: Int {
        switch self {
        case .timers: 14
        case .startSleep, .stopSleep: 12
        default: 1
        }
    }

    /// The MQTT message for one or more commands.
    public static func payload(_ commands: [ACCommand]) -> Data {
        var message: [String: Any] = ["ki": commands.first?.kind ?? 1, "cnt": "an", "sid": "1"]
        for command in commands { message.merge(command.fields) { _, new in new } }
        return (try? JSONSerialization.data(withJSONObject: message, options: .sortedKeys)) ?? Data()
    }

    /// Whether a status message shows every field these commands set.
    public static func isConfirmed(_ commands: [ACCommand], by status: [String: Any]) -> Bool {
        for command in commands {
            switch command {
            case .timers(let off, let on):
                // The AC reports the times on its own clock, which can be a little out.
                guard let reported = status["actm"] as? [Any], reported.count == 2 else { return false }
                let state = ACState(fields: ["actm": reported])
                for (expected, actual) in [(off, state.offTimer), (on, state.onTimer)] {
                    switch (expected, actual) {
                    case (nil, nil): continue
                    case let (expected?, actual?) where abs(expected.timeIntervalSince(actual)) < 120: continue
                    default: return false
                    }
                }
                continue
            case .startSleep(let profile):
                guard ACState.string(status["acsp"]) == profile.id else { return false }
                continue
            case .stopSleep:
                guard ACState.string(status["acsp"]) == "none" else { return false }
                continue
            default:
                break
            }
            for (key, expected) in command.fields {
                guard let actual = status[key] else { return false }
                if let lhs = ACState.double(expected), let rhs = ACState.double(actual) {
                    if abs(lhs - rhs) > 0.01 { return false }
                } else if ACState.string(expected) != ACState.string(actual) {
                    return false
                }
            }
        }
        return true
    }

    static func format(_ temperature: Double) -> String {
        let clamped = min(ACState.temperatureRange.upperBound, max(ACState.temperatureRange.lowerBound, temperature))
        let halves = (clamped * 2).rounded() / 2
        return halves == halves.rounded() ? String(Int(halves)) : String(halves)
    }

    /// Whole minutes from now, as the MirAIe app sends them, so a timer lands on the minute;
    /// -1 for no timer.
    static func seconds(until date: Date?) -> Int {
        guard let date else { return -1 }
        let minute = (date.timeIntervalSince1970 / 60).rounded() * 60
        return max(60, Int((minute - Date().timeIntervalSince1970).rounded()))
    }

    static func louver(_ position: Int) -> Int { min(Louver.positions.upperBound, max(Louver.swing, position)) }
}
