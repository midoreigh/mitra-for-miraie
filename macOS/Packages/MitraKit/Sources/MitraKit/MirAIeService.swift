import Foundation

/// Signs in, keeps a valid MirAIe session and sends commands. The app's menu bar panel, its
/// widgets and Siri all go through here, so any of them works even when the others aren't running.
public actor MirAIeService {
    public static let shared = MirAIeService()

    private let clientId = "mitra-\(UUID().uuidString.prefix(8).lowercased())"
    private var signingIn: Task<MirAIeAPI.Session, Error>?

    public init() {}

    public var isSignedIn: Bool { SecretStore.credentials != nil }

    // MARK: - Account

    /// Signs in, loads the account's ACs and stores the credentials for later sessions.
    @discardableResult
    public func signIn(username: String, password: String) async throws -> [Device] {
        let session = try await MirAIeAPI.signIn(username: username, password: password)
        let devices = try await loadHome(session: session)
        SecretStore.credentials = Credentials(username: username, password: password)
        return devices
    }

    public func signOut() {
        SecretStore.credentials = nil
        SecretStore.session = nil
        SharedStore.shared.clear()
    }

    /// A session that MirAIe should still accept, signing in again if needed.
    public func session(forceRefresh: Bool = false) async throws -> MirAIeAPI.Session {
        if !forceRefresh, let session = SecretStore.session, session.isFresh, session.homeId != nil {
            return session
        }
        if let signingIn { return try await signingIn.value }
        guard let credentials = SecretStore.credentials else { throw MitraError.notSignedIn }
        let task = Task {
            let session = try await MirAIeAPI.signIn(username: credentials.username, password: credentials.password)
            _ = try await loadHome(session: session)
            return SecretStore.session ?? session
        }
        signingIn = task
        defer { signingIn = nil }
        return try await task.value
    }

    @discardableResult
    public func refreshDevices() async throws -> [Device] {
        try await withSession { try await self.loadHome(session: $0) }
    }

    private func loadHome(session: MirAIeAPI.Session) async throws -> [Device] {
        let home = try await MirAIeAPI.home(session: session)
        let devices = home.devices.filter { $0.kind == .airConditioner }
        guard !devices.isEmpty else { throw MitraError.noDevices }
        var session = session
        session.homeId = home.id
        SecretStore.session = session
        SharedStore.shared.devices = devices
        return devices
    }

    // MARK: - Devices

    public func device(id: String?) throws -> Device {
        let store = SharedStore.shared
        guard !store.devices.isEmpty else { throw isSignedIn ? MitraError.noDevices : MitraError.notSignedIn }
        guard let device = id.map({ id in store.devices.first { $0.id == id } }) ?? store.selectedDevice else {
            throw MitraError.deviceNotFound
        }
        return device
    }

    /// Fetches the AC's state from the cloud and caches it for the widgets.
    @discardableResult
    public func refreshState(of device: Device) async throws -> ACState {
        let state = try await withSession { try await MirAIeAPI.state(deviceId: device.id, session: $0) }
        SharedStore.shared.save(state, for: device.id)
        SharedStore.shared.learnCapabilities(from: state, for: device.id)
        return state
    }

    /// The cached state if it's recent, otherwise a fresh one.
    public func currentState(of device: Device, maxAge: TimeInterval = 60) async throws -> ACState {
        if let cached = SharedStore.shared.state(for: device.id), -cached.updatedAt.timeIntervalSinceNow < maxAge {
            return cached
        }
        return try await refreshState(of: device)
    }

    /// Sends commands over a short-lived MQTT connection and returns the AC's state afterwards:
    /// confirmed by the AC when it answers in time, otherwise the expected state.
    @discardableResult
    public func send(_ commands: [ACCommand], to device: Device) async throws -> ACState {
        var state = SharedStore.shared.state(for: device.id) ?? ACState()
        let payload = ACCommand.payload(commands)
        let reply = try await withSession { session in
            try await MQTTClient.publishOnce(clientId: self.clientId, username: session.homeId ?? "",
                                             password: session.accessToken,
                                             topic: device.controlTopic, payload: payload,
                                             awaiting: device.statusTopic) { data in
                guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
                return ACCommand.isConfirmed(commands, by: json)
            }
        }
        if let reply, let json = (try? JSONSerialization.jsonObject(with: reply)) as? [String: Any] {
            state.apply(json)
        } else {
            commands.forEach { state.apply($0) }
        }
        state.isOnline = true
        SharedStore.shared.save(state, for: device.id)
        return state
    }

    /// Runs `body` with a session, signing in again once if MirAIe says it has expired.
    private func withSession<T: Sendable>(_ body: @Sendable (MirAIeAPI.Session) async throws -> T) async throws -> T {
        do {
            return try await body(try await session())
        } catch MitraError.sessionExpired {
            return try await body(try await session(forceRefresh: true))
        }
    }
}
