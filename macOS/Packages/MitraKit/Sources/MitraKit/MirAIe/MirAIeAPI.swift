import Foundation

/// MirAIe cloud REST API (unofficial). Endpoints and app constants follow the community MirAIe
/// clients: github.com/abdulghanitech/hawadaar, github.com/rkzofficial/miraie-ac.
public enum MirAIeAPI {
    public static let mqttHost = "mqtt.miraie.in"
    public static let mqttPort: UInt16 = 8883

    private static let clientId = "PBcMcfG19njNCL8AOgvRzIC8AjQa"
    private static let scope = "an_14214235325"
    private static let loginURL = URL(string: "https://auth.miraie.in/simplifi/v1/userManagement/login")!
    private static let homesURL = URL(string: "https://app.miraie.in/simplifi/v1/homeManagement/homes")!
    private static let devicesURL = "https://app.miraie.in/simplifi/v1/deviceManagement/devices/"

    public struct Session: Codable, Sendable {
        public var accessToken: String
        public var expiresAt: Date
        /// The MQTT username; filled in once the home is known.
        public var homeId: String?

        public var isFresh: Bool { expiresAt.timeIntervalSinceNow > 120 }
    }

    public struct Home: Sendable {
        public let id: String
        public let devices: [Device]
    }

    public enum LoginIdentifier: Equatable, Sendable {
        case email(String)
        /// E.164 number, e.g. "+919876543210".
        case mobile(String)

        var field: String {
            switch self {
            case .email: "email"
            case .mobile: "mobile"
            }
        }

        public var value: String {
            switch self {
            case .email(let value), .mobile(let value): value
            }
        }
    }

    /// Interprets what the user typed as an email or a mobile number, or nil if it's neither.
    /// Indian numbers (MirAIe's home market) may omit the country code; others need a leading "+".
    public static func loginIdentifier(for username: String) -> LoginIdentifier? {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("@") {
            return trimmed.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
                ? .email(trimmed) : nil
        }
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isNumber || " +-()".contains($0) }) else { return nil }
        let digits = trimmed.filter(\.isNumber)
        if trimmed.hasPrefix("+") {
            return (8...15).contains(digits.count) ? .mobile("+" + digits) : nil
        }
        switch digits.count {
        case 10: return .mobile("+91" + digits)
        case 11 where digits.hasPrefix("0"): return .mobile("+91" + digits.dropFirst())
        case 12 where digits.hasPrefix("91"): return .mobile("+" + digits)
        default: return nil
        }
    }

    public static func signIn(username: String, password: String) async throws -> Session {
        guard let identifier = loginIdentifier(for: username) else {
            throw MitraError.signInFailed("Enter a 10-digit mobile number or an email address.")
        }
        let body: [String: Any] = ["clientId": clientId, "scope": scope, "password": password,
                                   identifier.field: identifier.value]
        var request = URLRequest(url: loginURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let token = json?["accessToken"] as? String else {
            throw MitraError.signInFailed((json?["message"] as? String) ?? "HTTP \(status)")
        }
        let lifetime = ACState.double(json?["expiresIn"]) ?? 3600
        return Session(accessToken: token, expiresAt: Date().addingTimeInterval(lifetime))
    }

    public static func home(session: Session) async throws -> Home {
        guard let home = (try await get(homesURL, session: session) as? [[String: Any]])?.first,
              let homeId = home["homeId"] as? String else {
            throw MitraError.server("No home found on this MirAIe account.")
        }
        let devices = (home["spaces"] as? [[String: Any]] ?? []).flatMap { space in
            (space["devices"] as? [[String: Any]] ?? []).compactMap { device -> Device? in
                guard let id = device["deviceId"] as? String,
                      let topic = (device["topic"] as? [String])?.first else { return nil }
                let category = (device["category"] as? String ?? "AC").uppercased()
                return Device(id: id,
                              name: device["deviceName"] as? String ?? "AC",
                              kind: category.contains("AC") ? .airConditioner : .unsupported,
                              topicBase: topic,
                              room: space["spaceName"] as? String)
            }
        }
        return Home(id: homeId, devices: devices)
    }

    public static func state(deviceId: String, session: Session) async throws -> ACState {
        let url = URL(string: devicesURL + deviceId + "/mobile/status")!
        return ACState(fields: try await get(url, session: session) as? [String: Any] ?? [:])
    }

    private static func get(_ url: URL, session: Session) async throws -> Any {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: return try JSONSerialization.jsonObject(with: data)
        case 401, 403: throw MitraError.sessionExpired
        case let status: throw MitraError.server("MirAIe returned HTTP \(status).")
        }
    }
}

public enum MitraError: LocalizedError, Equatable, Sendable {
    case notSignedIn
    case signInFailed(String)
    case sessionExpired
    case noDevices
    case deviceNotFound
    case deviceOffline(String)
    case server(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notSignedIn: "Sign in to MirAIe in Mitra first."
        case .signInFailed(let message): "Sign-in failed: \(message)"
        case .sessionExpired: "Your MirAIe session expired."
        case .noDevices: "No air conditioners found on this MirAIe account."
        case .deviceNotFound: "That air conditioner is no longer on your MirAIe account."
        case .deviceOffline(let name): "\(name) is offline."
        case .server(let message): message
        case .timeout: "MirAIe didn't respond in time."
        }
    }
}
