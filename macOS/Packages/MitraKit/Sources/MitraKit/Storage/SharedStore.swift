import Foundation
import Security

/// Where the app, its widgets and its Siri intents share data. With an App Group (set as
/// `MitraAppGroup` in each target's Info.plist) they all see the same values; without one,
/// such as an unsigned build or tests, each process falls back to its own storage.
public enum SharedContainer {
    public static let appGroup: String? = {
        // Only a group under a signing team ("ABCDE12345.com…") is usable on macOS.
        guard let group = Bundle.main.object(forInfoDictionaryKey: "MitraAppGroup") as? String,
              group.range(of: #"^[A-Z0-9]{10}\."#, options: .regularExpression) != nil else { return nil }
        return group
    }()

    /// UserDefaults is thread-safe.
    nonisolated(unsafe) public static let defaults: UserDefaults = appGroup.flatMap(UserDefaults.init(suiteName:)) ?? .standard

    /// Posted (across processes) whenever an intent or widget changes an AC, so the app refreshes.
    public static let didChangeNotification = Notification.Name("com.midoreigh.mitra.didChange")
}

public struct Credentials: Codable, Equatable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// Non-secret state that the widgets and intents read: the device list, the last known
/// state of each AC and the user's chosen AC.
public struct SharedStore: Sendable {
    public static let shared = SharedStore()

    private enum Key {
        static let devices = "devices"
        static let states = "states"
        static let selectedDevice = "selectedDevice"
        static let capabilities = "capabilities"
    }

    private var defaults: UserDefaults { SharedContainer.defaults }

    public var devices: [Device] {
        get { decode([Device].self, Key.devices) ?? [] }
        nonmutating set { encode(newValue, Key.devices) }
    }

    public var states: [String: ACState] {
        get { decode([String: ACState].self, Key.states) ?? [:] }
        nonmutating set { encode(newValue, Key.states) }
    }

    public var selectedDeviceId: String? {
        get { defaults.string(forKey: Key.selectedDevice) }
        nonmutating set { defaults.set(newValue, forKey: Key.selectedDevice) }
    }

    /// The chosen AC, or the first one.
    public var selectedDevice: Device? {
        devices.first { $0.id == selectedDeviceId } ?? devices.first
    }

    public func state(for deviceId: String) -> ACState? { states[deviceId] }

    public func save(_ state: ACState, for deviceId: String) {
        var all = states
        all[deviceId] = state
        states = all
    }

    public var capabilities: [String: ACCapabilities] {
        get { decode([String: ACCapabilities].self, Key.capabilities) ?? [:] }
        nonmutating set { encode(newValue, Key.capabilities) }
    }

    public func capabilities(for deviceId: String) -> ACCapabilities { capabilities[deviceId] ?? ACCapabilities() }

    public func setCapabilities(_ value: ACCapabilities, for deviceId: String) {
        var all = capabilities
        all[deviceId] = value
        capabilities = all
    }

    /// Learns from a state the AC reported (not one we predicted after sending a command).
    @discardableResult
    public func learnCapabilities(from state: ACState, for deviceId: String) -> ACCapabilities {
        let current = capabilities(for: deviceId)
        let learned = current.learning(from: state)
        if learned != current { setCapabilities(learned, for: deviceId) }
        return learned
    }

    public func clear() {
        [Key.devices, Key.states, Key.selectedDevice, Key.capabilities].forEach(defaults.removeObject(forKey:))
    }

    private func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

/// Secrets in the Keychain, shared through the App Group's access group when there is one.
public enum SecretStore {
    private static let service = "com.midoreigh.mitra"

    public static var credentials: Credentials? {
        get { read(Credentials.self, account: "credentials") }
        set { write(newValue, account: "credentials") }
    }

    public static var session: MirAIeAPI.Session? {
        get { read(MirAIeAPI.Session.self, account: "session") }
        set { write(newValue, account: "session") }
    }

    /// The shared keychain needs a provisioning profile; without one (errSecMissingEntitlement)
    /// secrets stay in this process's own keychain, so the app works but widgets and Siri can't
    /// see them.
    private static func queries(account: String) -> [[String: Any]] {
        let local: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        guard let group = SharedContainer.appGroup else { return [local] }
        var shared = local
        shared[kSecAttrAccessGroup as String] = group
        shared[kSecUseDataProtectionKeychain as String] = true
        return [shared, local]
    }

    private static func read<T: Decodable>(_ type: T.Type, account: String) -> T? {
        for query in queries(account: account) {
            var request = query
            request[kSecReturnData as String] = true
            request[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            if SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
                return try? JSONDecoder().decode(type, from: data)
            }
        }
        return nil
    }

    private static func write<T: Encodable>(_ value: T?, account: String) {
        let queries = queries(account: account)
        // Delete everywhere before adding: a query without an access group matches items in
        // every group the app has, so deleting after adding would remove the new item.
        queries.forEach { SecItemDelete($0 as CFDictionary) }
        guard let data = value.flatMap({ try? JSONEncoder().encode($0) }) else { return }
        for query in queries {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            if SecItemAdd(item as CFDictionary, nil) == errSecSuccess { return }
        }
    }
}
