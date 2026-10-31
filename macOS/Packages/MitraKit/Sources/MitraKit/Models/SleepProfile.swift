import Foundation

/// A sleep profile: a set temperature for each hour of the night, run by the AC itself once
/// started. MirAIe keeps the profiles made in its app to itself, so Mitra keeps its own.
public struct SleepProfile: Codable, Hashable, Identifiable, Sendable {
    /// Sent to the AC, which reports it back while the profile runs.
    public var id: String
    public var name: String
    /// One set temperature per hour, in whole degrees.
    public var temperatures: [Double]
    /// Whether the AC turns off once the last hour is over.
    public var turnsOffAtEnd: Bool

    public static let hours = 1...8

    public init(id: String = SleepProfile.newId(), name: String, temperatures: [Double], turnsOffAtEnd: Bool) {
        self.id = id
        self.name = name
        self.temperatures = temperatures
        self.turnsOffAtEnd = turnsOffAtEnd
    }

    /// The AC's own profile ("Default" in the MirAIe app): the current set temperature for three
    /// hours, a degree warmer for three, two degrees warmer for two, then off. The AC works it
    /// out from wherever it's set, so `temperatures` is only the template the MirAIe app sends.
    public static let gentle = SleepProfile(id: "default", name: "Gentle",
                                            temperatures: [24, 24, 24, 25, 25, 25, 26, 26], turnsOffAtEnd: true)

    public var isGentle: Bool { id == Self.gentle.id }

    /// For a new profile: an hour at 26 °C, then two at 27 °C, then off.
    public static func new() -> SleepProfile {
        SleepProfile(name: "New profile", temperatures: [26, 27, 27], turnsOffAtEnd: true)
    }

    /// The hourly temperatures as the AC takes them: "26.0", with "00.0" as a last hour to turn off.
    public var wireTemperatures: [String] {
        temperatures.map { String(format: "%04.1f", $0) } + (turnsOffAtEnd ? ["00.0"] : [])
    }

    /// The temperatures the AC will set hour by hour, given its set temperature now.
    public func schedule(from setpoint: Double) -> [Double] {
        guard isGentle else { return temperatures }
        return temperatures.map { setpoint + $0 - temperatures[0] }
    }

    /// Ten random lowercase letters and digits, like the IDs the MirAIe app makes.
    public static func newId() -> String {
        String((0..<10).map { _ in "0123456789abcdef".randomElement()! })
    }
}
