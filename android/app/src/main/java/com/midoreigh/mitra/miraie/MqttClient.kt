package com.midoreigh.mitra.miraie

import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull
import java.io.IOException
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

/**
 * Minimal MQTT-over-TLS client. Connection state lives on one private thread, where the
 * listener is called too; each connection reads on a thread of its own.
 */
class MqttClient(
    private val host: String = MirAIeApi.MQTT_HOST,
    private val port: Int = MirAIeApi.MQTT_PORT,
) {
    enum class State { DISCONNECTED, CONNECTING, CONNECTED }

    interface Listener {
        fun stateChanged(state: State) {}
        fun message(topic: String, payload: ByteArray) {}
        /** The broker refused the credentials (CONNACK 4 or 5), usually an expired token. */
        fun authRejected() {}
    }

    private val keepAlive = 60
    private val queue = Executors.newSingleThreadScheduledExecutor { Thread(it, "Mitra.MQTT").apply { isDaemon = true } }
    @Volatile var listener: Listener = object : Listener {}
    private var socket: Socket? = null
    private var output: OutputStream? = null
    private var pingTask: ScheduledFuture<*>? = null
    private var nextPacketId = 1
    private var topics: List<String> = emptyList()
    /** Which connection is current; a reader for an older one stops quietly. */
    private var generation = 0
    /** When the broker last sent anything; pings keep this fresh on a healthy connection. */
    @Volatile private var lastReceived = 0L

    fun connect(clientId: String, username: String, password: String, subscribe: List<String>) {
        post {
            teardown()
            topics = subscribe
            val current = ++generation
            listener.stateChanged(State.CONNECTING)
            Thread({ run(current, clientId, username, password) }, "Mitra.MQTT.read").apply { isDaemon = true }.start()
        }
    }

    fun disconnect() {
        post {
            // Also stops a connection that's still being made.
            generation++
            val active = socket != null
            if (active) send(MqttPacket.disconnect)
            teardown()
            if (active) listener.stateChanged(State.DISCONNECTED)
        }
    }

    fun publish(topic: String, payload: ByteArray) {
        post { send(MqttPacket.publish(topic, payload)) }
    }

    /** Stops the client's thread; it can't be used again. */
    fun shutdown() {
        queue.shutdown()
    }

    // Internals

    private fun run(current: Int, clientId: String, username: String, password: String) {
        val socket: SSLSocket
        try {
            val factory = SSLSocketFactory.getDefault() as SSLSocketFactory
            val plain = Socket()
            plain.connect(InetSocketAddress(host, port), 10_000)
            socket = factory.createSocket(plain, host, port, true) as SSLSocket
            socket.startHandshake()
        } catch (e: IOException) {
            Log.w(TAG, "Couldn't connect: $e")
            post { if (current == generation) closeWithNotice() }
            return
        }
        post {
            if (current != generation) {
                runCatching { socket.close() }
                return@post
            }
            this.socket = socket
            output = socket.outputStream
            lastReceived = System.currentTimeMillis()
            send(MqttPacket.connect(clientId, username, password, keepAlive))
        }
        val decoder = MqttPacket.Decoder()
        val buffer = ByteArray(65536)
        try {
            val input = socket.inputStream
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                lastReceived = System.currentTimeMillis()
                val packets = decoder.append(buffer.copyOf(count))
                post { if (current == generation) packets.forEach(::handle) }
            }
        } catch (e: IOException) {
            Log.i(TAG, "Connection closed: $e")
        }
        post { if (current == generation) closeWithNotice() }
    }

    /** Runs on the client's thread, unless the client has been shut down. */
    private fun post(block: () -> Unit) {
        try {
            queue.execute(block)
        } catch (_: RejectedExecutionException) {
        }
    }

    private fun teardown() {
        pingTask?.cancel(false)
        pingTask = null
        runCatching { socket?.close() }
        socket = null
        output = null
    }

    private fun closeWithNotice() {
        generation++
        teardown()
        listener.stateChanged(State.DISCONNECTED)
    }

    private fun send(data: ByteArray) {
        val out = output ?: return
        try {
            out.write(data)
            out.flush()
        } catch (_: IOException) {
            closeWithNotice()
        }
    }

    private fun handle(packet: MqttPacket.Incoming) {
        when (packet) {
            is MqttPacket.Incoming.ConnAck -> if (packet.returnCode == 0) {
                Log.i(TAG, "Connected")
                startPing()
                if (topics.isNotEmpty()) {
                    send(MqttPacket.subscribe(nextPacketId, topics))
                    nextPacketId = nextPacketId % 65535 + 1
                }
                listener.stateChanged(State.CONNECTED)
            } else {
                Log.w(TAG, "Broker refused the connection: ${packet.returnCode}")
                closeWithNotice()
                if (packet.returnCode == 4 || packet.returnCode == 5) listener.authRejected()
            }
            is MqttPacket.Incoming.Publish -> listener.message(packet.topic, packet.payload)
            else -> Unit
        }
    }

    private fun startPing() {
        val interval = keepAlive / 2L
        pingTask = queue.scheduleWithFixedDelay({
            // A connection can die silently (e.g. across a network change); without a ping
            // response within the keep-alive period, drop it so the owner reconnects.
            if (System.currentTimeMillis() - lastReceived > keepAlive * 1000L) closeWithNotice()
            else send(MqttPacket.pingRequest)
        }, interval, interval, TimeUnit.SECONDS)
    }

    companion object {
        private const val TAG = "MitraMQTT"

        /**
         * Connects, publishes one message and waits for a status message that [accepts],
         * then disconnects. Returns that message, or null if none arrived before [timeoutMs]
         * (QoS 0 has no delivery receipt, so the command may still have worked).
         * Used by the widget and Quick Settings tile, which run without the app's live connection.
         */
        suspend fun publishOnce(
            clientId: String, username: String, password: String,
            topic: String, payload: ByteArray, awaiting: String,
            timeoutMs: Long = 5_000,
            accepts: (ByteArray) -> Boolean,
        ): ByteArray? {
            val client = MqttClient()
            val result = CompletableDeferred<ByteArray?>()
            val published = AtomicBoolean(false)
            client.listener = object : Listener {
                override fun stateChanged(state: State) {
                    when (state) {
                        State.CONNECTED -> {
                            client.publish(topic, payload)
                            published.set(true)
                        }
                        State.DISCONNECTED -> if (published.get()) result.complete(null)
                        else result.completeExceptionally(MitraException.Server("Couldn't reach MirAIe."))
                        State.CONNECTING -> Unit
                    }
                }

                override fun message(topic: String, payload: ByteArray) {
                    if (topic == awaiting && published.get() && accepts(payload)) result.complete(payload)
                }

                override fun authRejected() {
                    result.completeExceptionally(MitraException.SessionExpired())
                }
            }
            client.connect(clientId, username, password, listOf(awaiting))
            try {
                return withTimeoutOrNull(timeoutMs) { result.await() }
                    ?: if (published.get()) null else throw MitraException.Timeout()
            } finally {
                client.disconnect()
                client.shutdown()
            }
        }
    }
}
