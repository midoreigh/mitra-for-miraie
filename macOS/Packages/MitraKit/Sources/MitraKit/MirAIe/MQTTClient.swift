import Foundation
import Network

/// Minimal MQTT-over-TLS client. All state lives on a private serial queue, and the
/// handlers are called on it too.
public final class MQTTClient: @unchecked Sendable {
    public enum State: Sendable { case disconnected, connecting, connected }

    public struct Handlers: Sendable {
        public var stateChanged: @Sendable (State) -> Void = { _ in }
        public var message: @Sendable (_ topic: String, _ payload: Data) -> Void = { _, _ in }
        /// The broker refused the credentials (CONNACK 4 or 5), usually an expired token.
        public var authRejected: @Sendable () -> Void = {}

        public init() {}
    }

    private let host: String
    private let port: UInt16
    private let keepAlive: UInt16 = 60
    private let queue = DispatchQueue(label: "Mitra.MQTT")
    private var handlers = Handlers()
    private var connection: NWConnection?
    private var decoder = MQTTPacket.Decoder()
    private var pingTimer: DispatchSourceTimer?
    private var nextPacketId: UInt16 = 1
    private var topics: [String] = []
    /// When the broker last sent anything; pings keep this fresh on a healthy connection.
    private var lastReceived = Date()

    public init(host: String = MirAIeAPI.mqttHost, port: UInt16 = MirAIeAPI.mqttPort) {
        self.host = host
        self.port = port
    }

    public func setHandlers(_ handlers: Handlers) {
        queue.async { self.handlers = handlers }
    }

    public func connect(clientId: String, username: String, password: String, subscribe topics: [String]) {
        queue.async { [self] in
            teardown()
            self.topics = topics
            handlers.stateChanged(.connecting)
            let conn = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: .tls)
            connection = conn
            conn.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    send(MQTTPacket.connect(clientId: clientId, username: username,
                                            password: password, keepAlive: keepAlive))
                    receive()
                case .failed, .cancelled:
                    closeWithNotice()
                case .waiting:
                    // No route (offline, or Wi-Fi still waking up): fail fast so the owner retries.
                    closeWithNotice()
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    public func disconnect() {
        queue.async { [self] in
            guard connection != nil else { return }
            send(MQTTPacket.disconnect)
            teardown()
            handlers.stateChanged(.disconnected)
        }
    }

    public func publish(topic: String, payload: Data) {
        queue.async { [self] in send(MQTTPacket.publish(topic: topic, payload: payload)) }
    }

    // MARK: - Internals

    private func teardown() {
        pingTimer?.cancel()
        pingTimer = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        decoder.reset()
    }

    private func closeWithNotice() {
        guard connection != nil else { return }
        teardown()
        handlers.stateChanged(.disconnected)
    }

    private func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                lastReceived = Date()
                for packet in decoder.append(data) { handle(packet) }
            }
            if isComplete || error != nil {
                closeWithNotice()
                return
            }
            receive()
        }
    }

    private func handle(_ packet: MQTTPacket.Incoming) {
        switch packet {
        case .connAck(0):
            startPing()
            if !topics.isEmpty {
                send(MQTTPacket.subscribe(packetId: nextPacketId, topics: topics))
                nextPacketId &+= 1
            }
            handlers.stateChanged(.connected)
        case .connAck(let code):
            closeWithNotice()
            if code == 4 || code == 5 { handlers.authRejected() }
        case .publish(let topic, let payload):
            handlers.message(topic, payload)
        default:
            break
        }
    }

    private func startPing() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let interval = DispatchTimeInterval.seconds(Int(keepAlive) / 2)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            // A connection can die silently (e.g. across sleep); without a ping response
            // within the keep-alive period, drop it so the owner reconnects.
            if Date().timeIntervalSince(lastReceived) > TimeInterval(keepAlive) {
                closeWithNotice()
            } else {
                send(MQTTPacket.pingRequest)
            }
        }
        timer.resume()
        pingTimer = timer
    }
}

extension MQTTClient {
    /// Connects, publishes one message and waits for a status message that `accepts`,
    /// then disconnects. Returns that message, or nil if none arrived before `timeout`
    /// (QoS 0 has no delivery receipt, so the command may still have worked).
    /// Used by Siri and widgets, which run without the app's long-lived connection.
    public static func publishOnce(clientId: String, username: String, password: String,
                                   topic: String, payload: Data,
                                   awaiting statusTopic: String,
                                   timeout: TimeInterval = 5,
                                   accepts: @escaping @Sendable (Data) -> Bool) async throws -> Data? {
        let client = MQTTClient()
        let gate = ResumeGate<Data?>()
        defer { client.disconnect() }
        return try await withCheckedThrowingContinuation { continuation in
            gate.continuation = continuation
            let published = Flag()
            var handlers = Handlers()
            handlers.stateChanged = { state in
                switch state {
                case .connected:
                    client.publish(topic: topic, payload: payload)
                    published.set()
                case .disconnected:
                    if published.isSet { gate.resume(returning: nil) } else { gate.resume(throwing: MitraError.server("Couldn't reach MirAIe.")) }
                case .connecting:
                    break
                }
            }
            handlers.message = { incoming, data in
                if incoming == statusTopic, published.isSet, accepts(data) { gate.resume(returning: data) }
            }
            handlers.authRejected = { gate.resume(throwing: MitraError.sessionExpired) }
            client.setHandlers(handlers)
            client.connect(clientId: clientId, username: username, password: password, subscribe: [statusTopic])
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if published.isSet { gate.resume(returning: nil) } else { gate.resume(throwing: MitraError.timeout) }
            }
        }
    }
}

/// Resumes a continuation exactly once, whichever callback gets there first.
private final class ResumeGate<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    var continuation: CheckedContinuation<Value, Error>?

    func resume(returning value: Value) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Value, Error>? {
        lock.withLock {
            defer { continuation = nil }
            return continuation
        }
    }
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.withLock { value } }
    func set() { lock.withLock { value = true } }
}
