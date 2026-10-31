package com.midoreigh.mitra.model

import java.util.Locale

/**
 * A sleep profile: a set temperature for each hour of the night, run by the AC itself once
 * started. MirAIe keeps the profiles made in its app to itself, so Mitra keeps its own.
 */
data class SleepProfile(
    /** Sent to the AC, which reports it back while the profile runs. */
    val id: String = newId(),
    val name: String,
    /** One set temperature per hour, in whole degrees. */
    val temperatures: List<Double>,
    /** Whether the AC turns off once the last hour is over. */
    val turnsOffAtEnd: Boolean,
) {
    val isGentle: Boolean get() = id == GENTLE.id

    /** The hourly temperatures as the AC takes them: "26.0", with "00.0" as a last hour to turn off. */
    val wireTemperatures: List<String>
        get() = temperatures.map { String.format(Locale.US, "%04.1f", it) } + (if (turnsOffAtEnd) listOf("00.0") else emptyList())

    /** The temperatures the AC will set hour by hour, given its set temperature now. */
    fun schedule(from: Double): List<Double> =
        if (!isGentle) temperatures else temperatures.map { from + it - temperatures[0] }

    /** "26° 27° 27°, then off", or how Gentle works. */
    val summary: String
        get() {
            if (isGentle) return "Your temperature, then 1° and 2° warmer, over 8 h, then off"
            val hours = temperatures.joinToString(" ") { "${it.toInt()}°" }
            return if (turnsOffAtEnd) "$hours, then off" else hours
        }

    /**
     * "Hour 2 of 3". For a profile started in the MirAIe app, which hour means little without
     * its length, so just where it came from.
     */
    fun progress(hour: Int?): String {
        if (temperatures.isEmpty()) return "Started in the MirAIe app"
        if (hour == null) return "Running"
        return "Hour ${minOf(hour + 1, temperatures.size)} of ${temperatures.size}"
    }

    companion object {
        val HOURS = 1..8

        /**
         * The AC's own profile ("Default" in the MirAIe app): the current set temperature for
         * three hours, a degree warmer for three, two degrees warmer for two, then off. The AC
         * works it out from wherever it's set, so [temperatures] is only the template the
         * MirAIe app sends.
         */
        val GENTLE = SleepProfile("default", "Gentle", listOf(24.0, 24.0, 24.0, 25.0, 25.0, 25.0, 26.0, 26.0), true)

        /** For a new profile: an hour at 26 °C, then two at 27 °C, then off. */
        fun new() = SleepProfile(name = "New profile", temperatures = listOf(26.0, 27.0, 27.0), turnsOffAtEnd = true)

        /** One started in the MirAIe app: Mitra doesn't know its name or hours. */
        fun unknown(id: String) = SleepProfile(id, "Sleep profile", emptyList(), false)

        /** Ten random lowercase hex characters, like the IDs the MirAIe app makes. */
        fun newId(): String = (1..10).map { "0123456789abcdef".random() }.joinToString("")
    }
}
