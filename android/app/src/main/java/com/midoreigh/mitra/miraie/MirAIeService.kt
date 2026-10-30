package com.midoreigh.mitra.miraie

import android.content.Context
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.Device
import com.midoreigh.mitra.store.Credentials
import com.midoreigh.mitra.store.SecretStore
import com.midoreigh.mitra.store.SharedStore
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.util.UUID

/**
 * Signs in, keeps a valid MirAIe session and sends commands. The app, its widget and its
 * Quick Settings tile all go through here, so any of them works without the others.
 */
class MirAIeService(context: Context) {
    val secrets = SecretStore(context)
    val shared = SharedStore(context)

    private val clientId = "mitra-" + UUID.randomUUID().toString().take(8)
    private val signingIn = Mutex()

    val isSignedIn: Boolean get() = secrets.credentials != null

    /** Signs in, loads the account's ACs and stores the credentials for later sessions. */
    suspend fun signIn(username: String, password: String): List<Device> {
        val session = MirAIeApi.signIn(username, password)
        val devices = loadHome(session)
        secrets.credentials = Credentials(username, password)
        return devices
    }

    fun signOut() {
        secrets.credentials = null
        secrets.session = null
        shared.clear()
    }

    /** A session that MirAIe should still accept, signing in again if needed. */
    suspend fun session(forceRefresh: Boolean = false): MirAIeApi.Session {
        val before = secrets.session
        if (!forceRefresh && before != null && before.isFresh && before.homeId != null) return before
        return signingIn.withLock {
            // Someone else may have just refreshed it while this waited.
            val current = secrets.session
            if (current != null && current != before && current.isFresh && current.homeId != null) return@withLock current
            val credentials = secrets.credentials ?: throw MitraException.NotSignedIn()
            val session = MirAIeApi.signIn(credentials.username, credentials.password)
            loadHome(session)
            secrets.session ?: session
        }
    }

    suspend fun refreshDevices(): List<Device> = withSession { loadHome(it) }

    private suspend fun loadHome(session: MirAIeApi.Session): List<Device> {
        val home = MirAIeApi.home(session)
        if (home.devices.isEmpty()) throw MitraException.NoDevices()
        secrets.session = session.copy(homeId = home.id)
        shared.devices = home.devices
        return home.devices
    }

    /** Fetches the AC's state from the cloud and caches it for the widget. */
    suspend fun refreshState(device: Device): ACState {
        val state = withSession { MirAIeApi.state(device.id, it) }
        shared.save(state, device.id)
        shared.learnCapabilities(state, device.id)
        return state
    }

    /**
     * Sends commands over a short-lived MQTT connection and returns the AC's state afterwards:
     * confirmed by the AC when it answers in time, otherwise the expected state.
     */
    suspend fun send(commands: List<ACCommand>, device: Device): ACState {
        var state = shared.state(device.id) ?: ACState()
        val payload = JSONObject(ACCommand.message(commands)).toString().toByteArray()
        val reply = withSession { session ->
            MqttClient.publishOnce(
                clientId, session.homeId ?: "", session.accessToken,
                device.controlTopic, payload, device.statusTopic,
            ) { data ->
                runCatching { ACCommand.isConfirmed(commands, JSONObject(String(data)).toMap()) }.getOrDefault(false)
            }
        }
        val json = reply?.let { runCatching { JSONObject(String(it)).toMap() }.getOrNull() }
        state = if (json != null) state.applying(json) else state.applying(*commands.toTypedArray())
        state = state.copy(isOnline = true)
        shared.save(state, device.id)
        return state
    }

    /** Runs [body] with a session, signing in again once if MirAIe says it has expired. */
    private suspend fun <T> withSession(body: suspend (MirAIeApi.Session) -> T): T =
        try {
            body(session())
        } catch (e: MitraException.SessionExpired) {
            body(session(forceRefresh = true))
        }

    companion object {
        @Volatile private var instance: MirAIeService? = null

        fun get(context: Context): MirAIeService =
            instance ?: synchronized(this) {
                instance ?: MirAIeService(context.applicationContext).also { instance = it }
            }
    }
}
