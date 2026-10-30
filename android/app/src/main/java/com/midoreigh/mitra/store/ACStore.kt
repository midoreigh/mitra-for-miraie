package com.midoreigh.mitra.store

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.widget.Toast
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.midoreigh.mitra.miraie.MirAIeService
import com.midoreigh.mitra.miraie.MitraException
import com.midoreigh.mitra.miraie.MqttClient
import com.midoreigh.mitra.miraie.toMap
import com.midoreigh.mitra.model.ACCapabilities
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.model.ACMode
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.Converti
import com.midoreigh.mitra.model.Device
import com.midoreigh.mitra.model.FanSpeed
import com.midoreigh.mitra.widget.Surfaces
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID

enum class Phase { SIGNED_OUT, LOADING, READY, FAILED }

data class UiState(
    val phase: Phase = Phase.SIGNED_OUT,
    /** Why sign-in or loading failed, while [phase] is FAILED. */
    val error: String? = null,
    val devices: List<Device> = emptyList(),
    val states: Map<String, ACState> = emptyMap(),
    val selectedId: String? = null,
    /** Whether the live connection to MirAIe is up. */
    val isLive: Boolean = false,
    /**
     * Try the controls without touching the AC: commands only change what the app shows, and
     * status from the AC is ignored until it's switched off again, when the real state is restored.
     */
    val isPreviewing: Boolean = false,
    /** Showing a made-up AC, so the app can be tried without a MirAIe account. */
    val isDemo: Boolean = false,
    /** What each AC can do, so the app only offers what works. */
    val capabilities: Map<String, ACCapabilities> = emptyMap(),
    /** The username of the last sign-in attempt, to refill the form. */
    val lastUsername: String = "",
) {
    val selected: Device? get() = devices.firstOrNull { it.id == selectedId } ?: devices.firstOrNull()
    val state: ACState get() = selected?.let { states[it.id] } ?: ACState()
    val selectedCapabilities: ACCapabilities get() = selected?.let { capabilities[it.id] } ?: ACCapabilities()
    val canControl: Boolean get() = selected != null && state.isOnline
}

/**
 * The app's live view of the account: while the app is in the foreground a long-lived MQTT
 * connection keeps every AC's state current, and changes are mirrored to the widget and tile.
 */
class ACStore private constructor(private val context: Context) {
    private val service = MirAIeService.get(context)
    private val shared = service.shared
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val mqtt = MqttClient()
    private val clientId = "mitra-android-" + UUID.randomUUID().toString().take(8)

    private val _ui = MutableStateFlow(UiState())
    val ui: StateFlow<UiState> = _ui
    private val current get() = _ui.value

    private var statesBeforePreview: Map<String, ACState>? = null
    private var reconnectJob: Job? = null
    private var surfacesJob: Job? = null
    private var isForeground = false

    /**
     * Commands sent but not yet confirmed, per AC. Until the AC reports the new value (or a few
     * seconds pass), older values it reports for those fields are ignored, so a control
     * doesn't flick back and forth after a tap.
     */
    private val pending = mutableMapOf<String, MutableList<Pair<ACCommand, Long>>>()

    init {
        val devices = shared.devices
        _ui.value = UiState(
            phase = if (service.isSignedIn) (if (devices.isEmpty()) Phase.LOADING else Phase.READY) else Phase.SIGNED_OUT,
            devices = devices,
            states = devices.mapNotNull { d -> shared.state(d.id)?.let { d.id to it } }.toMap(),
            selectedId = shared.selectedDeviceId,
            capabilities = devices.associate { it.id to shared.capabilities(it.id) },
            lastUsername = service.secrets.credentials?.username ?: "",
        )
        configureMqtt()
        observeSystem()
    }

    // Account

    /** Signs in and goes live. The form keeps showing its own progress until there's an outcome. */
    suspend fun signIn(username: String, password: String) {
        _ui.update { it.copy(lastUsername = username) }
        try {
            val devices = service.signIn(username, password)
            _ui.update { it.copy(devices = devices, selectedId = it.selectedId ?: devices.firstOrNull()?.id) }
            start()
        } catch (e: Exception) {
            _ui.update { it.copy(phase = Phase.FAILED, error = e.message ?: "Something went wrong.") }
        }
    }

    /** Opens the app on a made-up AC in preview mode, kept only in memory. */
    fun startDemo() {
        val state = ACState(
            isOn = true, mode = ACMode.COOL, setpoint = 24.0, fan = FanSpeed.AUTO,
            roomTemperature = 27.5, converti = Converti.OFF, isOnline = true,
        )
        _ui.update {
            it.copy(
                devices = listOf(Device(DEMO_ID, "Living Room AC", "demo")),
                states = mapOf(DEMO_ID to state), selectedId = DEMO_ID,
                isDemo = true, isPreviewing = true, phase = Phase.READY, error = null,
            )
        }
    }

    fun clearError() {
        if (current.phase == Phase.FAILED) _ui.update { it.copy(phase = Phase.SIGNED_OUT, error = null) }
    }

    fun signOut() {
        reconnectJob?.cancel()
        mqtt.disconnect()
        service.signOut()
        _ui.value = UiState()
        scheduleSurfacesUpdate()
    }

    fun select(deviceId: String) {
        if (!current.isDemo) shared.selectedDeviceId = deviceId
        _ui.update { it.copy(selectedId = deviceId) }
        scheduleSurfacesUpdate()
    }

    fun setPreviewing(on: Boolean) {
        val ui = current
        if (ui.isPreviewing == on) return
        if (ui.isDemo) {
            if (!on) _ui.value = UiState(lastUsername = ui.lastUsername)
            return
        }
        if (on) {
            statesBeforePreview = ui.states
            _ui.update { it.copy(isPreviewing = true) }
        } else {
            // Back to the real settings at once, then catch up on anything the AC changed
            // meanwhile (its status was ignored while previewing).
            val real = statesBeforePreview ?: ui.states
            statesBeforePreview = null
            _ui.update { it.copy(isPreviewing = false, states = real) }
            scope.launch { start() }
        }
    }

    /** In preview mode, pretends the AC dropped off (or came back on) the network. */
    fun togglePreviewOnline() {
        val ui = current
        val device = ui.selected ?: return
        if (!ui.isPreviewing) return
        _ui.update { it.copy(states = it.states + (device.id to ui.state.copy(isOnline = !ui.state.isOnline))) }
    }

    fun setCapabilities(value: ACCapabilities, deviceId: String) {
        _ui.update { it.copy(capabilities = it.capabilities + (deviceId to value)) }
        if (!current.isDemo) shared.setCapabilities(value, deviceId)
    }

    /** Loads the device list and every AC's state, then goes live. */
    suspend fun start() {
        if (current.isDemo || !service.isSignedIn) return
        try {
            val devices = service.refreshDevices()
            val states = current.states.toMutableMap()
            for (device in devices) {
                runCatching { service.refreshState(device) }.getOrNull()?.let { states[device.id] = it }
            }
            _ui.update {
                it.copy(
                    devices = devices, states = if (it.isPreviewing) it.states else states,
                    capabilities = devices.associate { d -> d.id to shared.capabilities(d.id) },
                    phase = Phase.READY, error = null,
                )
            }
            scheduleSurfacesUpdate()
            connect()
        } catch (e: MitraException.NotSignedIn) {
            _ui.update { it.copy(phase = Phase.SIGNED_OUT) }
        } catch (e: Exception) {
            // Keep showing cached devices; the reconnect loop will try again.
            _ui.update {
                if (it.devices.isEmpty()) it.copy(phase = Phase.FAILED, error = e.message) else it.copy(phase = Phase.READY)
            }
            scheduleReconnect()
        }
    }

    // Commands

    fun send(vararg commands: ACCommand) {
        val ui = current
        val device = ui.selected ?: return
        val state = ui.state.applying(*commands)
        if (ui.isPreviewing) {
            // Only on screen: not saved for the widget, not sent.
            _ui.update { it.copy(states = it.states + (device.id to state)) }
            return
        }
        update(state, device)
        val until = System.currentTimeMillis() + 3_000
        pending.getOrPut(device.id) { mutableListOf() } += commands.map { it to until }
        val list = commands.toList()
        if (ui.isLive) {
            mqtt.publish(device.controlTopic, JSONObject(ACCommand.message(list)).toString().toByteArray())
        } else {
            scope.launch {
                try {
                    update(service.send(list, device), device)
                } catch (e: Exception) {
                    Toast.makeText(context, e.message ?: "Couldn't reach the AC.", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    // Live connection

    private fun configureMqtt() {
        mqtt.listener = object : MqttClient.Listener {
            override fun stateChanged(state: MqttClient.State) {
                scope.launch { connectionChanged(state) }
            }

            override fun message(topic: String, payload: ByteArray) {
                val json = runCatching { JSONObject(String(payload)).toMap() }.getOrNull() ?: return
                scope.launch { received(topic, json) }
            }

            override fun authRejected() {
                scope.launch { connect(forceRefresh = true) }
            }
        }
    }

    private suspend fun connect(forceRefresh: Boolean = false) {
        val devices = current.devices
        if (devices.isEmpty() || current.isDemo || !isForeground) return
        val session = runCatching { service.session(forceRefresh) }.getOrNull()
        if (session == null) {
            scheduleReconnect()
            return
        }
        val topics = devices.flatMap { listOf(it.statusTopic, it.connectionTopic) }
        mqtt.connect(clientId, session.homeId ?: "", session.accessToken, topics)
    }

    private fun connectionChanged(state: MqttClient.State) {
        _ui.update { it.copy(isLive = state == MqttClient.State.CONNECTED) }
        if (state == MqttClient.State.DISCONNECTED && current.phase == Phase.READY) scheduleReconnect()
    }

    private fun scheduleReconnect() {
        reconnectJob?.cancel()
        reconnectJob = scope.launch {
            delay(5_000)
            if (current.phase == Phase.READY || current.phase == Phase.LOADING) connect()
        }
    }

    private fun received(topic: String, fields: Map<String, Any?>) {
        val ui = current
        if (ui.isPreviewing) return
        val device = ui.devices.firstOrNull { topic.startsWith(it.topicBase + "/") } ?: return
        val now = System.currentTimeMillis()
        val json = fields.toMutableMap()
        val waiting = pending[device.id].orEmpty().filter { it.second > now }.toMutableList()
        waiting.removeAll { ACCommand.isConfirmed(listOf(it.first), json) }
        for ((command, _) in waiting) command.fields.keys.forEach(json::remove)
        pending[device.id] = waiting
        var state = (ui.states[device.id] ?: ACState()).applying(json) // connectionStatus carries just "onlineStatus"
        if (topic == device.statusTopic) state = state.copy(isOnline = true)
        update(state, device)
        val learned = shared.learnCapabilities(state, device.id)
        _ui.update { it.copy(capabilities = it.capabilities + (device.id to learned)) }
    }

    private fun update(state: ACState, device: Device) {
        val old = current.states[device.id]
        _ui.update { it.copy(states = it.states + (device.id to state)) }
        shared.save(state, device.id)
        if (old == null || !old.looksSame(state)) scheduleSurfacesUpdate()
    }

    // System events

    private fun observeSystem() {
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                isForeground = true
                reloadFromSharedStore()
                if (service.isSignedIn && !current.isDemo) scope.launch { start() }
            }

            override fun onStop(owner: LifecycleOwner) {
                // No live connection in the background; the widget and tile connect on demand.
                isForeground = false
                reconnectJob?.cancel()
                mqtt.disconnect()
                _ui.update { it.copy(isLive = false) }
            }
        })
        val connectivity = context.getSystemService(ConnectivityManager::class.java)
        connectivity.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // A new network: the old connection is likely dead.
                scope.launch {
                    delay(1_000)
                    if (isForeground && current.phase == Phase.READY && !current.isDemo) connect()
                }
            }
        })
    }

    /** The widget or tile may have changed an AC while the app was away. */
    private fun reloadFromSharedStore() {
        if (current.isPreviewing) return
        val newer = current.devices.mapNotNull { d ->
            shared.state(d.id)?.takeIf { it.updatedAt > (current.states[d.id]?.updatedAt ?: 0) }?.let { d.id to it }
        }
        if (newer.isNotEmpty()) _ui.update { it.copy(states = it.states + newer) }
    }

    /** Coalesce bursts of changes into one widget and tile refresh. */
    private fun scheduleSurfacesUpdate() {
        surfacesJob?.cancel()
        surfacesJob = scope.launch {
            delay(1_500)
            Surfaces.refresh(context)
        }
    }

    companion object {
        private const val DEMO_ID = "demo"

        @Volatile private var instance: ACStore? = null

        fun get(context: Context): ACStore =
            instance ?: synchronized(this) {
                instance ?: ACStore(context.applicationContext).also { instance = it }
            }
    }
}

/** Equal in everything the widget shows. */
private fun ACState.looksSame(other: ACState): Boolean =
    isOn == other.isOn && setpoint == other.setpoint && mode == other.mode && fan == other.fan &&
        isOnline == other.isOnline &&
        ((roomTemperature ?: 0.0) * 2).toInt() == ((other.roomTemperature ?: 0.0) * 2).toInt()
