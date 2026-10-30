package com.midoreigh.mitra.miraie

import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.Device
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * MirAIe cloud REST API (unofficial). Endpoints and app constants follow the community MirAIe
 * clients: github.com/abdulghanitech/hawadaar, github.com/rkzofficial/miraie-ac.
 */
object MirAIeApi {
    const val MQTT_HOST = "mqtt.miraie.in"
    const val MQTT_PORT = 8883

    private const val CLIENT_ID = "PBcMcfG19njNCL8AOgvRzIC8AjQa"
    private const val SCOPE = "an_14214235325"
    private const val LOGIN_URL = "https://auth.miraie.in/simplifi/v1/userManagement/login"
    private const val HOMES_URL = "https://app.miraie.in/simplifi/v1/homeManagement/homes"
    private const val DEVICES_URL = "https://app.miraie.in/simplifi/v1/deviceManagement/devices/"

    data class Session(
        val accessToken: String,
        val expiresAt: Long,
        /** The MQTT username; filled in once the home is known. */
        val homeId: String? = null,
    ) {
        val isFresh: Boolean get() = expiresAt - System.currentTimeMillis() > 120_000
    }

    data class Home(val id: String, val devices: List<Device>)

    sealed class LoginIdentifier(val field: String, val value: String) {
        class Email(value: String) : LoginIdentifier("email", value)
        /** E.164 number, e.g. "+919876543210". */
        class Mobile(value: String) : LoginIdentifier("mobile", value)

        override fun equals(other: Any?) = other is LoginIdentifier && other.field == field && other.value == value
        override fun hashCode() = field.hashCode() * 31 + value.hashCode()
        override fun toString() = "$field:$value"
    }

    private val emailPattern = Regex("""^[^@\s]+@[^@\s]+\.[^@\s]+$""")

    /**
     * Interprets what the user typed as an email or a mobile number, or null if it's neither.
     * Indian numbers (MirAIe's home market) may omit the country code; others need a leading "+".
     */
    fun loginIdentifier(username: String): LoginIdentifier? {
        val trimmed = username.trim()
        if ("@" in trimmed) return if (emailPattern.matches(trimmed)) LoginIdentifier.Email(trimmed) else null
        if (trimmed.isEmpty() || !trimmed.all { it.isDigit() || it in " +-()" }) return null
        val digits = trimmed.filter(Char::isDigit)
        if (trimmed.startsWith("+")) {
            return if (digits.length in 8..15) LoginIdentifier.Mobile("+$digits") else null
        }
        return when {
            digits.length == 10 -> LoginIdentifier.Mobile("+91$digits")
            digits.length == 11 && digits.startsWith("0") -> LoginIdentifier.Mobile("+91" + digits.drop(1))
            digits.length == 12 && digits.startsWith("91") -> LoginIdentifier.Mobile("+$digits")
            else -> null
        }
    }

    suspend fun signIn(username: String, password: String): Session {
        val identifier = loginIdentifier(username)
            ?: throw MitraException.SignInFailed("Enter a 10-digit mobile number or an email address.")
        val body = JSONObject()
            .put("clientId", CLIENT_ID)
            .put("scope", SCOPE)
            .put("password", password)
            .put(identifier.field, identifier.value)
        val (status, text) = request(LOGIN_URL, body = body.toString())
        val json = runCatching { JSONObject(text) }.getOrNull()
        val token = json?.optString("accessToken").orEmpty()
        if (status != 200 || token.isEmpty()) {
            throw MitraException.SignInFailed(json?.optString("message")?.takeIf { it.isNotEmpty() } ?: "HTTP $status")
        }
        val lifetime = ACState.double(json?.opt("expiresIn")) ?: 3600.0
        return Session(token, System.currentTimeMillis() + (lifetime * 1000).toLong())
    }

    suspend fun home(session: Session): Home {
        val homes = JSONArray(get(HOMES_URL, session))
        val home = homes.optJSONObject(0) ?: throw MitraException.Server("No home found on this MirAIe account.")
        val homeId = home.optString("homeId").ifEmpty { throw MitraException.Server("No home found on this MirAIe account.") }
        val devices = mutableListOf<Device>()
        val spaces = home.optJSONArray("spaces") ?: JSONArray()
        for (i in 0 until spaces.length()) {
            val space = spaces.optJSONObject(i) ?: continue
            val list = space.optJSONArray("devices") ?: continue
            for (j in 0 until list.length()) {
                val device = list.optJSONObject(j) ?: continue
                val id = device.optString("deviceId").ifEmpty { null } ?: continue
                val topic = device.optJSONArray("topic")?.optString(0)?.ifEmpty { null } ?: continue
                val category = device.optString("category", "AC").uppercase()
                if ("AC" !in category) continue
                devices += Device(
                    id = id,
                    name = device.optString("deviceName").ifEmpty { "AC" },
                    topicBase = topic,
                    room = space.optString("spaceName").ifEmpty { null },
                )
            }
        }
        return Home(homeId, devices)
    }

    suspend fun state(deviceId: String, session: Session): ACState =
        ACState().applying(JSONObject(get(DEVICES_URL + deviceId + "/mobile/status", session)).toMap())

    private suspend fun get(url: String, session: Session): String {
        val (status, text) = request(url, bearer = session.accessToken)
        return when (status) {
            200 -> text
            401, 403 -> throw MitraException.SessionExpired()
            else -> throw MitraException.Server("MirAIe returned HTTP $status.")
        }
    }

    private suspend fun request(url: String, body: String? = null, bearer: String? = null): Pair<Int, String> =
        withContext(Dispatchers.IO) {
            val connection = URL(url).openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = 15_000
                connection.readTimeout = 15_000
                connection.setRequestProperty("Accept", "application/json")
                bearer?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
                if (body != null) {
                    connection.requestMethod = "POST"
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.outputStream.use { it.write(body.toByteArray()) }
                }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                status to (stream?.bufferedReader()?.use { it.readText() } ?: "")
            } catch (e: IOException) {
                throw MitraException.Server("Couldn't reach MirAIe. Check your connection.")
            } finally {
                connection.disconnect()
            }
        }
}

/** A JSON object's top-level fields, for [ACState.applying]. */
fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { key -> opt(key) }

sealed class MitraException(message: String) : Exception(message) {
    class NotSignedIn : MitraException("Sign in to MirAIe in Mitra first.")
    class SignInFailed(reason: String) : MitraException("Sign-in failed: $reason")
    class SessionExpired : MitraException("Your MirAIe session expired.")
    class NoDevices : MitraException("No air conditioners found on this MirAIe account.")
    class Server(message: String) : MitraException(message)
    class Timeout : MitraException("MirAIe didn't respond in time.")
}
