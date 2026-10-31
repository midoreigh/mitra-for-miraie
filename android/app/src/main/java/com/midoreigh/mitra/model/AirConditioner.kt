package com.midoreigh.mitra.model

import org.json.JSONArray
import kotlin.math.abs
import kotlin.math.roundToInt

enum class ACMode(val raw: String) {
    // Auto first, as on the fan speeds.
    AUTO("auto"), COOL("cool"), DRY("dry"), FAN("fan"), HEAT("heat");

    val title: String get() = raw.replaceFirstChar { it.uppercase() }

    /** Fan-only mode has no temperature setpoint. */
    val usesSetpoint: Boolean get() = this != FAN

    companion object {
        fun of(raw: String?): ACMode? = entries.firstOrNull { it.raw == raw }
    }
}

enum class FanSpeed(val raw: String) {
    AUTO("auto"), QUIET("quiet"), LOW("low"), MEDIUM("medium"), HIGH("high");

    /** Named as in the MirAIe app. */
    val title: String get() = raw.replaceFirstChar { it.uppercase() }

    companion object {
        fun of(raw: String?): FanSpeed? = entries.firstOrNull { it.raw == raw }
    }
}

/**
 * Panasonic Converti7: run the AC at a share of its full cooling capacity, in percent, to
 * save power or cool harder. 0 is off (normal operation).
 */
object Converti {
    const val OFF = 0
    val levels = listOf(40, 55, 70, 80, 90, 100, 110)
}

/**
 * Louver positions. MirAIe uses 0 for continuous swing and 1–5 for fixed positions.
 * Vertically 1 is nearly level and 5 points down. Horizontally they're out of order (seen on
 * a Panasonic unit): 1 points straight ahead, 2 far left, 3 left, 4 right and 5 far right.
 */
object Louver {
    const val SWING = 0
    val positions = 1..5

    /** MirAIe's left/right positions, from far left to far right. */
    val horizontalLeftToRight = listOf(2, 3, 1, 4, 5)

    /** Where a MirAIe left/right position sits from the left: 1 (far left) to 5 (far right). */
    fun horizontalSlot(position: Int): Int =
        horizontalLeftToRight.indexOf(position).let { if (it < 0) 2 else it } + 1

    fun verticalLabel(position: Int): String = when (position) {
        SWING -> "Swing"
        1 -> "Highest"
        2 -> "High"
        3 -> "Middle"
        4 -> "Low"
        else -> "Lowest"
    }

    fun horizontalLabel(position: Int): String {
        if (position == SWING) return "Swing"
        return when (horizontalSlot(position)) {
            1 -> "Far left"
            2 -> "Left"
            3 -> "Centre"
            4 -> "Right"
            else -> "Far right"
        }
    }
}

/**
 * What an AC can do. MirAIe doesn't say, so this starts from what most MirAIe units have
 * (no heating, no nanoe™ X) and learns more from what the AC itself reports. The user can
 * also switch features on in Settings.
 */
data class ACCapabilities(
    val heat: Boolean = false,
    val nanoe: Boolean = false,
    /** Panasonic's Converti7 cooling levels; most MirAIe-connected Panasonic units have them. */
    val converti: Boolean = true,
) {
    val modes: List<ACMode> get() = ACMode.entries.filter { it != ACMode.HEAT || heat }

    /** Adds anything a state reported by the AC shows it can do. */
    fun learning(state: ACState): ACCapabilities = copy(
        heat = heat || state.mode == ACMode.HEAT,
        nanoe = nanoe || state.nanoe == true,
    )
}

/** One air conditioner's state, decoded from MirAIe status fields. */
data class ACState(
    val isOn: Boolean = false,
    val setpoint: Double = 24.0,
    val mode: ACMode = ACMode.COOL,
    val fan: FanSpeed = FanSpeed.AUTO,
    val verticalLouver: Int = Louver.SWING,
    val horizontalLouver: Int = Louver.SWING,
    val eco: Boolean = false,
    val powerful: Boolean = false,
    /** The Converti7 level in percent; 0 or null when off. */
    val converti: Int? = null,
    val display: Boolean = true,
    /**
     * null when the AC doesn't report its nanoe™ X ionizer. Many units report it as off even
     * without one, so [ACCapabilities.nanoe] decides whether to offer it.
     */
    val nanoe: Boolean? = null,
    val roomTemperature: Double? = null,
    val isOnline: Boolean = true,
    /** Signal strength the AC reports for its own Wi-Fi connection, in dBm. */
    val wifiSignal: Int? = null,
    val firmware: String? = null,
    /** When the AC will turn itself off or on, in milliseconds since 1970, if a timer is set. */
    val offTimer: Long? = null,
    val onTimer: Long? = null,
    /** The ID of the sleep profile the AC is running, and which hour of it (from 0). */
    val sleepProfile: String? = null,
    val sleepHour: Int? = null,
    val updatedAt: Long = 0,
) {
    /** Merges a full or partial MirAIe status message. */
    fun applying(fields: Map<String, Any?>): ACState {
        var s = this
        string(fields["V"])?.takeIf { it.isNotEmpty() }?.let { s = s.copy(firmware = it) }
        string(fields["ps"])?.let { s = s.copy(isOn = it == "on") }
        double(fields["actmp"])?.let { s = s.copy(setpoint = it) }
        ACMode.of(string(fields["acmd"]))?.let { s = s.copy(mode = it) }
        FanSpeed.of(string(fields["acfs"]))?.let { s = s.copy(fan = it) }
        double(fields["acvs"])?.let { s = s.copy(verticalLouver = it.toInt()) }
        double(fields["achs"])?.let { s = s.copy(horizontalLouver = it.toInt()) }
        string(fields["acem"])?.let { s = s.copy(eco = it == "on") }
        string(fields["acpm"])?.let { s = s.copy(powerful = it == "on") }
        double(fields["cnv"])?.let { s = s.copy(converti = it.toInt()) }
        string(fields["acdc"])?.let { s = s.copy(display = it != "off") }
        string(fields["acng"])?.let { s = s.copy(nanoe = it == "on") }
        string(fields["onlineStatus"])?.let { s = s.copy(isOnline = it == "true") }
        double(fields["rssi"])?.let { s = s.copy(wifiSignal = it.toInt()) }
        string(fields["rmtmp"])?.let { value ->
            roomTemperature(value, s.firmware)?.let { s = s.copy(roomTemperature = it) }
        }
        // Timers come back as the time they go off; -1 when not set.
        list(fields["actm"])?.takeIf { it.size == 2 }?.let { s = s.copy(offTimer = timer(it[0]), onTimer = timer(it[1])) }
        string(fields["acsp"])?.let { value ->
            val id = value.takeUnless { it == "none" || it == "off" || it.isEmpty() }
            s = s.copy(sleepProfile = id, sleepHour = if (id == null) null else s.sleepHour)
        }
        double(fields["sleep_indx"])?.let { s = s.copy(sleepHour = it.toInt()) }
        return s.copy(updatedAt = System.currentTimeMillis())
    }

    /** Applies commands locally, for an optimistic update before the AC confirms them. */
    fun applying(vararg commands: ACCommand): ACState =
        commands.fold(this) { state, command ->
            val now = System.currentTimeMillis()
            when (command) {
                is ACCommand.Timers -> state.copy(offTimer = command.off, onTimer = command.on, updatedAt = now)
                is ACCommand.StartSleep -> state.copy(
                    sleepProfile = command.profile.id, sleepHour = 0, updatedAt = now,
                    setpoint = command.profile.schedule(state.setpoint).firstOrNull() ?: state.setpoint,
                )
                is ACCommand.StopSleep -> state.copy(sleepProfile = null, sleepHour = null, updatedAt = now)
                else -> state.applying(command.fields)
            }
        }

    /** What the AC is doing, in a few words, e.g. "Cooling to 24°". */
    val summary: String
        get() {
            if (!isOnline) return "Offline"
            if (!isOn) return "Off"
            val target = formatTemperature(setpoint)
            return when (mode) {
                ACMode.COOL -> "Cooling to $target"
                ACMode.HEAT -> "Heating to $target"
                ACMode.DRY -> "Drying at $target"
                ACMode.FAN -> "Fan only"
                ACMode.AUTO -> "Auto at $target"
            }
        }

    val roomTemperatureText: String? get() = roomTemperature?.let { "%.1f°".format(it) }

    companion object {
        const val MIN_TEMPERATURE = 16.0
        const val MAX_TEMPERATURE = 30.0

        /**
         * Room temperature in °C. Firmware 3.02+ packs sub-degree precision as
         * "<fraction × 256>.<degrees>", e.g. "43.28" is 28 + 43/256 ≈ 28.17 °C.
         */
        fun roomTemperature(value: String, firmware: String?): Double? {
            val version = (firmware ?: "").split(".").mapNotNull { part -> part.filter(Char::isDigit).toIntOrNull() }
            val packed = version.size >= 2 && (version[0] > 3 || (version[0] == 3 && version[1] >= 2))
            val parts = value.split(".")
            // Some 3.02 units still send a plain reading ("26.5"); unpacking that gives 5.1°, so
            // only trust the packed form when it comes out as a believable room temperature.
            if (packed && parts.size == 2) {
                val fraction = parts[0].toDoubleOrNull()
                val degrees = parts[1].toDoubleOrNull()
                if (fraction != null && degrees != null && fraction < 256 && degrees in 10.0..50.0) {
                    return degrees + fraction / 256
                }
            }
            return value.toDoubleOrNull()
        }

        /** "24°", or "24.5°" for halves. */
        fun formatTemperature(value: Double): String =
            if (value == Math.rint(value)) "${value.toInt()}°" else "%.1f°".format(value)

        fun string(value: Any?): String? = when (value) {
            is String -> value
            is Int, is Long -> value.toString()
            is Number -> value.toDouble().let { if (it == Math.rint(it)) it.toLong().toString() else it.toString() }
            is Boolean -> value.toString()
            else -> null
        }

        fun double(value: Any?): Double? = when (value) {
            is Number -> value.toDouble()
            is String -> value.trim().toDoubleOrNull()
            else -> null
        }

        /** A JSON array, as decoded from a message or written in a command. */
        fun list(value: Any?): List<Any?>? = when (value) {
            is JSONArray -> (0 until value.length()).map { value.opt(it) }
            is List<*> -> value
            else -> null
        }

        private fun timer(value: Any?): Long? = double(value)?.takeIf { it > 0 }?.let { (it * 1000).toLong() }
    }
}

/** A control command, published as JSON to the AC's `<topic>/control` MQTT topic. */
sealed interface ACCommand {
    data class Power(val on: Boolean) : ACCommand
    data class Temperature(val value: Double) : ACCommand
    data class Mode(val mode: ACMode) : ACCommand
    data class Fan(val speed: FanSpeed) : ACCommand
    data class VerticalLouver(val position: Int) : ACCommand
    data class HorizontalLouver(val position: Int) : ACCommand
    data class Eco(val on: Boolean) : ACCommand
    data class Powerful(val on: Boolean) : ACCommand
    data class Display(val on: Boolean) : ACCommand
    data class Nanoe(val on: Boolean) : ACCommand
    data class ConvertiLevel(val level: Int) : ACCommand
    /**
     * Sets both timers at once, in milliseconds since 1970: the AC replaces both with every
     * command, so the one not being changed has to be sent again. null clears a timer.
     */
    data class Timers(val off: Long?, val on: Long?) : ACCommand
    data class StartSleep(val profile: SleepProfile) : ACCommand
    /** Stops the running profile, by its ID; [temperatures] as last sent, if known. */
    data class StopSleep(val id: String, val temperatures: List<String>) : ACCommand

    /** The status fields this command changes. */
    val fields: Map<String, Any>
        get() = when (this) {
            is Power -> mapOf("ps" to onOff(on))
            is Temperature -> mapOf("actmp" to format(value))
            is Mode -> mapOf("acmd" to mode.raw)
            is Fan -> mapOf("acfs" to speed.raw)
            is VerticalLouver -> mapOf("acvs" to louver(position))
            is HorizontalLouver -> mapOf("achs" to louver(position))
            // Eco and Powerful are mutually exclusive; the MirAIe app sets 26 °C when enabling Eco.
            is Eco -> if (on) mapOf("acem" to "on", "acpm" to "off", "actmp" to "26") else mapOf("acem" to "off")
            is Powerful -> if (on) mapOf("acpm" to "on", "acem" to "off") else mapOf("acpm" to "off")
            is Display -> mapOf("acdc" to onOff(on))
            is Nanoe -> mapOf("acng" to onOff(on))
            // Converti replaces Eco and Powerful, as in the MirAIe app.
            is ConvertiLevel -> if (level == Converti.OFF) mapOf("cnv" to Converti.OFF)
            else mapOf("cnv" to level, "acem" to "off", "acpm" to "off")
            // Sent as seconds from now, which the AC adds to its own clock.
            is Timers -> mapOf("actm" to listOf(seconds(off), seconds(on)))
            is StartSleep -> mapOf("acsp" to "on", "pid" to profile.id, "temps" to profile.wireTemperatures)
            is StopSleep -> mapOf("acsp" to "off", "pid" to id, "temps" to temperatures)
        }

    /** The MirAIe app's command kind for each; the AC seems to accept 1 for everything else. */
    val kind: Int
        get() = when (this) {
            is Timers -> 14
            is StartSleep, is StopSleep -> 12
            else -> 1
        }

    companion object {
        /** The MQTT message for one or more commands, as a JSON object's fields. */
        fun message(commands: List<ACCommand>): Map<String, Any> {
            val message = sortedMapOf<String, Any>("ki" to (commands.firstOrNull()?.kind ?: 1), "cnt" to "an", "sid" to "1")
            commands.forEach { message.putAll(it.fields) }
            return message
        }

        /** Whether a status message shows every field these commands set. */
        fun isConfirmed(commands: List<ACCommand>, status: Map<String, Any?>): Boolean =
            commands.all { command ->
                when (command) {
                    is Timers -> {
                        // The AC reports the times on its own clock, which can be a little out.
                        val reported = ACState.list(status["actm"])?.takeIf { it.size == 2 } ?: return@all false
                        val state = ACState().applying(mapOf("actm" to reported))
                        return@all listOf(command.off to state.offTimer, command.on to state.onTimer).all { (expected, actual) ->
                            if (expected == null || actual == null) expected == actual else abs(expected - actual) < 120_000
                        }
                    }
                    is StartSleep -> return@all ACState.string(status["acsp"]) == command.profile.id
                    is StopSleep -> return@all ACState.string(status["acsp"]) == "none"
                    else -> {}
                }
                command.fields.all { (key, expected) ->
                    val actual = status[key] ?: return@all false
                    val lhs = ACState.double(expected)
                    val rhs = ACState.double(actual)
                    if (lhs != null && rhs != null) abs(lhs - rhs) <= 0.01
                    else ACState.string(expected) == ACState.string(actual)
                }
            }

        fun format(temperature: Double): String {
            val clamped = temperature.coerceIn(ACState.MIN_TEMPERATURE, ACState.MAX_TEMPERATURE)
            val halves = (clamped * 2).roundToInt() / 2.0
            return if (halves == Math.rint(halves)) halves.toInt().toString() else halves.toString()
        }

        /**
         * Whole minutes from now, as the MirAIe app sends them, so a timer lands on the minute;
         * -1 for no timer.
         */
        fun seconds(until: Long?, now: Long = System.currentTimeMillis()): Int {
            if (until == null) return -1
            val minute = Math.round(until / 60_000.0) * 60_000
            return maxOf(60, Math.round((minute - now) / 1000.0).toInt())
        }

        private fun louver(position: Int) = position.coerceIn(Louver.SWING, Louver.positions.last)
        private fun onOff(on: Boolean) = if (on) "on" else "off"
    }
}

/** An air conditioner on the user's MirAIe account. */
data class Device(
    val id: String,
    val name: String,
    /** MQTT topic prefix, e.g. "<userId>/<homeId>/<deviceId>". */
    val topicBase: String,
    /** The room the device is in, as named in the MirAIe app. */
    val room: String? = null,
) {
    val controlTopic: String get() = "$topicBase/control"
    val statusTopic: String get() = "$topicBase/status"
    val connectionTopic: String get() = "$topicBase/connectionStatus"
}
