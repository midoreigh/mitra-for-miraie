import AppKit
import Observation
import WidgetKit
import MitraKit

/// The menu bar app's live view of the account: a long-lived MQTT connection keeps every
/// AC's state current, and changes are mirrored to the widgets.
@MainActor @Observable
final class ACStore {
    enum Phase: Equatable { case signedOut, loading, ready, failed(String) }

    private(set) var phase: Phase = .signedOut
    private(set) var devices: [Device] = []
    private(set) var states: [String: ACState] = [:]
    /// Whether the live connection to MirAIe is up.
    private(set) var isLive = false
    /// Try the controls without touching the AC: commands only change what the panel shows,
    /// and status from the AC is ignored until it's switched off again, when the real state
    /// is reloaded.
    var isPreviewing = false {
        didSet {
            guard oldValue, !isPreviewing else { return }
            Task { await start() }
        }
    }
    /// What each AC can do, so the panel only offers what works.
    private(set) var capabilities: [String: ACCapabilities] = [:]
    /// The username of the last sign-in attempt, to refill the form if the panel was closed.
    private(set) var lastUsername = SecretStore.credentials?.username ?? ""

    var selectedId: String? {
        didSet {
            SharedStore.shared.selectedDeviceId = selectedId
            scheduleWidgetReload()
        }
    }

    var selected: Device? { devices.first { $0.id == selectedId } ?? devices.first }
    var state: ACState { selected.flatMap { states[$0.id] } ?? ACState() }
    var selectedCapabilities: ACCapabilities { selected.flatMap { capabilities[$0.id] } ?? ACCapabilities() }
    var canControl: Bool { selected != nil && state.isOnline }

    private let service = MirAIeService.shared
    private let mqtt = MQTTClient()
    private let clientId = "mitra-app-\(UUID().uuidString.prefix(8).lowercased())"
    private var reconnectTask: Task<Void, Never>?
    private var widgetReloadTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    /// Commands sent but not yet confirmed, per AC. Until the AC reports the new value (or a few
    /// seconds pass), older values it reports for those fields are ignored, so a control
    /// doesn't flick back and forth after a click.
    private var pending: [String: [(command: ACCommand, until: Date)]] = [:]

    init() {
        let shared = SharedStore.shared
        devices = shared.devices
        states = shared.states
        selectedId = shared.selectedDeviceId
        capabilities = shared.capabilities
        configureMQTT()
        observeSystem()
        if SecretStore.credentials != nil {
            phase = devices.isEmpty ? .loading : .ready
            Task { await start() }
        }
    }

    // MARK: - Account

    /// Signs in and goes live. Leaves `phase` alone until there's an outcome, so the sign-in
    /// form (and what's typed in it) stays on screen, showing its own progress.
    func signIn(username: String, password: String) async {
        lastUsername = username
        do {
            devices = try await service.signIn(username: username, password: password)
            if selectedId == nil { selectedId = devices.first?.id }
            await start()
            if phase == .signedOut {
                phase = .failed("Signed in, but couldn't save your account to the Keychain.")
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Clears a sign-in error, e.g. once the user starts fixing their details.
    func clearError() {
        if case .failed = phase { phase = .signedOut }
    }

    func signOut() {
        reconnectTask?.cancel()
        mqtt.disconnect()
        Task { await service.signOut() }
        devices = []
        states = [:]
        selectedId = nil
        phase = .signedOut
        scheduleWidgetReload()
    }

    /// Loads the device list and every AC's state, then goes live.
    func start() async {
        do {
            devices = try await service.refreshDevices()
            for device in devices {
                if let state = try? await service.refreshState(of: device) { states[device.id] = state }
            }
            capabilities = SharedStore.shared.capabilities
            phase = .ready
            scheduleWidgetReload()
            await connect()
        } catch MitraError.notSignedIn {
            phase = .signedOut
        } catch {
            // Keep showing cached devices; the reconnect loop will try again.
            phase = devices.isEmpty ? .failed(error.localizedDescription) : .ready
            scheduleReconnect()
        }
    }

    // MARK: - Commands

    func send(_ commands: ACCommand...) {
        guard let device = selected else { return }
        var state = states[device.id] ?? ACState()
        commands.forEach { state.apply($0) }
        if isPreviewing {
            // Only on screen: not saved for the widgets, not sent.
            states[device.id] = state
            return
        }
        update(state, for: device)
        let until = Date().addingTimeInterval(3)
        pending[device.id, default: []] += commands.map { ($0, until) }
        if isLive {
            mqtt.publish(topic: device.controlTopic, payload: ACCommand.payload(commands))
        } else {
            Task {
                do {
                    let confirmed = try await service.send(commands, to: device)
                    update(confirmed, for: device)
                } catch {
                    NSSound.beep()
                }
            }
        }
    }

    /// In preview mode, pretends the selected AC dropped off (or came back on) the network,
    /// to see how the panel handles it.
    func togglePreviewOnline() {
        guard isPreviewing, let device = selected else { return }
        var state = states[device.id] ?? ACState()
        state.isOnline.toggle()
        states[device.id] = state
    }

    func setCapabilities(_ value: ACCapabilities, for deviceId: String) {
        capabilities[deviceId] = value
        SharedStore.shared.setCapabilities(value, for: deviceId)
    }

    // MARK: - Live connection

    private func configureMQTT() {
        var handlers = MQTTClient.Handlers()
        handlers.stateChanged = { [weak self] state in
            Task { @MainActor in self?.connectionChanged(state) }
        }
        handlers.message = { [weak self] topic, payload in
            guard let json = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: json) else { return }
            Task { @MainActor in self?.received(topic: topic, json: data) }
        }
        handlers.authRejected = { [weak self] in
            Task { @MainActor in await self?.connect(forceRefresh: true) }
        }
        mqtt.setHandlers(handlers)
    }

    private func connect(forceRefresh: Bool = false) async {
        guard !devices.isEmpty, let session = try? await service.session(forceRefresh: forceRefresh) else {
            scheduleReconnect()
            return
        }
        let topics = devices.flatMap { [$0.statusTopic, $0.connectionTopic] }
        mqtt.connect(clientId: clientId, username: session.homeId ?? "", password: session.accessToken, subscribe: topics)
    }

    private func connectionChanged(_ state: MQTTClient.State) {
        isLive = state == .connected
        if state == .disconnected, phase == .ready { scheduleReconnect() }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, !Task.isCancelled, phase == .ready || phase == .loading else { return }
            await connect()
        }
    }

    private func received(topic: String, json data: Data) {
        guard !isPreviewing else { return }
        guard var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let device = devices.first(where: { topic.hasPrefix($0.topicBase + "/") }) else { return }
        let now = Date()
        var waiting = pending[device.id, default: []].filter { $0.until > now }
        waiting.removeAll { ACCommand.isConfirmed([$0.command], by: json) }
        for entry in waiting {
            entry.command.fields.keys.forEach { json.removeValue(forKey: $0) }
        }
        pending[device.id] = waiting
        var state = states[device.id] ?? ACState()
        state.apply(json) // a connectionStatus message carries just "onlineStatus"
        if topic == device.statusTopic { state.isOnline = true }
        update(state, for: device)
        capabilities[device.id] = SharedStore.shared.learnCapabilities(from: state, for: device.id)
    }

    private func update(_ state: ACState, for device: Device) {
        let old = states[device.id]
        states[device.id] = state
        SharedStore.shared.save(state, for: device.id)
        if old.map({ !$0.looksSame(as: state) }) ?? true { scheduleWidgetReload() }
    }

    // MARK: - System events

    private func observeSystem() {
        // After sleep the connection is likely dead and the token may have expired.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3)) // Wi-Fi needs a moment
                await self?.start()
            }
        })
        // Siri or a widget changed an AC from another process.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: SharedContainer.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reloadFromSharedStore() }
        })
    }

    private func reloadFromSharedStore() {
        for (id, state) in SharedStore.shared.states where state.updatedAt > (states[id]?.updatedAt ?? .distantPast) {
            states[id] = state
        }
    }

    /// Widgets have a refresh budget; coalesce bursts of changes into one reload.
    private func scheduleWidgetReload() {
        widgetReloadTask?.cancel()
        widgetReloadTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadAllControls()
        }
    }
}

private extension ACState {
    /// Equal in everything a widget shows.
    func looksSame(as other: ACState) -> Bool {
        isOn == other.isOn && setpoint == other.setpoint && mode == other.mode && fan == other.fan
            && verticalLouver == other.verticalLouver && horizontalLouver == other.horizontalLouver
            && isOnline == other.isOnline && Int((roomTemperature ?? 0) * 2) == Int((other.roomTemperature ?? 0) * 2)
    }
}
