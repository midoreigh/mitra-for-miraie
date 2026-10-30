import Foundation

/// The kinds of device Mitra knows how to control. Only air conditioners today; new kinds
/// get their own state and command types alongside `ACState` and `ACCommand`.
public enum DeviceKind: String, Codable, Sendable {
    case airConditioner
    case unsupported
}

/// A device on the user's MirAIe account.
public struct Device: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var kind: DeviceKind
    /// MQTT topic prefix, e.g. "<userId>/<homeId>/<deviceId>".
    public var topicBase: String
    /// The room the device is in, as named in the MirAIe app.
    public var room: String?

    public init(id: String, name: String, kind: DeviceKind = .airConditioner, topicBase: String, room: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.topicBase = topicBase
        self.room = room
    }

    public var controlTopic: String { topicBase + "/control" }
    public var statusTopic: String { topicBase + "/status" }
    public var connectionTopic: String { topicBase + "/connectionStatus" }
}
