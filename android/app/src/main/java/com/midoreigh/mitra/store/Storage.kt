package com.midoreigh.mitra.store

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.midoreigh.mitra.miraie.MirAIeApi
import com.midoreigh.mitra.miraie.toMap
import com.midoreigh.mitra.model.ACCapabilities
import com.midoreigh.mitra.model.ACMode
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.Device
import com.midoreigh.mitra.model.FanSpeed
import com.midoreigh.mitra.model.SleepProfile
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class Credentials(val username: String, val password: String)

/**
 * The MirAIe login and session, encrypted with an AES key that lives in the Android Keystore
 * and never leaves it. They're only ever sent to MirAIe.
 */
class SecretStore(context: Context) {
    private val prefs = context.getSharedPreferences("secrets", Context.MODE_PRIVATE)

    var credentials: Credentials?
        get() = read("credentials")?.let { Credentials(it.getString("username"), it.getString("password")) }
        set(value) = write("credentials", value?.let { JSONObject().put("username", it.username).put("password", it.password) })

    var session: MirAIeApi.Session?
        get() = read("session")?.let {
            MirAIeApi.Session(it.getString("accessToken"), it.getLong("expiresAt"), it.optString("homeId").ifEmpty { null })
        }
        set(value) = write("session", value?.let {
            JSONObject().put("accessToken", it.accessToken).put("expiresAt", it.expiresAt).put("homeId", it.homeId ?: "")
        })

    private fun read(name: String): JSONObject? {
        val stored = prefs.getString(name, null) ?: return null
        return runCatching {
            val bytes = Base64.decode(stored, Base64.NO_WRAP)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes, 0, IV_LENGTH))
            JSONObject(String(cipher.doFinal(bytes, IV_LENGTH, bytes.size - IV_LENGTH), Charsets.UTF_8))
        }.getOrNull()
    }

    private fun write(name: String, value: JSONObject?) {
        if (value == null) {
            prefs.edit().remove(name).apply()
            return
        }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val sealed = cipher.iv + cipher.doFinal(value.toString().toByteArray(Charsets.UTF_8))
        prefs.edit().putString(name, Base64.encodeToString(sealed, Base64.NO_WRAP)).apply()
    }

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    private companion object {
        const val ALIAS = "mitra-secrets"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH = 12
    }
}

/**
 * What the app, its widget and its Quick Settings tile share: the account's ACs, their last
 * known state and features, and which AC the widget and tile control. Nothing secret.
 */
class SharedStore(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("shared", Context.MODE_PRIVATE)

    var devices: List<Device>
        get() = array("devices").map {
            Device(it.getString("id"), it.getString("name"), it.getString("topicBase"), it.optString("room").ifEmpty { null })
        }
        set(value) = put("devices", JSONArray(value.map {
            JSONObject().put("id", it.id).put("name", it.name).put("topicBase", it.topicBase).put("room", it.room ?: "")
        }).toString())

    var selectedDeviceId: String?
        get() = prefs.getString("selectedDeviceId", null)
        set(value) = prefs.edit().putString("selectedDeviceId", value).apply()

    val selectedDevice: Device?
        get() = devices.let { list -> list.firstOrNull { it.id == selectedDeviceId } ?: list.firstOrNull() }

    fun state(deviceId: String): ACState? =
        prefs.getString("state.$deviceId", null)?.let { runCatching { decodeState(JSONObject(it)) }.getOrNull() }

    fun save(state: ACState, deviceId: String) = put("state.$deviceId", encodeState(state).toString())

    fun capabilities(deviceId: String): ACCapabilities =
        prefs.getString("capabilities.$deviceId", null)?.let { json ->
            runCatching {
                JSONObject(json).let { ACCapabilities(it.optBoolean("heat"), it.optBoolean("nanoe"), it.optBoolean("converti", true)) }
            }.getOrNull()
        } ?: ACCapabilities()

    fun setCapabilities(value: ACCapabilities, deviceId: String) = put(
        "capabilities.$deviceId",
        JSONObject().put("heat", value.heat).put("nanoe", value.nanoe).put("converti", value.converti).toString(),
    )

    /** Records anything the AC's state shows it can do, and returns what it can do now. */
    fun learnCapabilities(state: ACState, deviceId: String): ACCapabilities {
        val known = capabilities(deviceId)
        val learned = known.learning(state)
        if (learned != known) setCapabilities(learned, deviceId)
        return learned
    }

    fun clear() = prefs.edit().clear().apply()

    private fun array(key: String): List<JSONObject> {
        val json = runCatching { JSONArray(prefs.getString(key, "[]")) }.getOrElse { JSONArray() }
        return (0 until json.length()).mapNotNull { json.optJSONObject(it) }
    }

    private fun put(key: String, value: String) = prefs.edit().putString(key, value).apply()

    private fun encodeState(s: ACState) = JSONObject()
        .put("isOn", s.isOn).put("setpoint", s.setpoint).put("mode", s.mode.raw).put("fan", s.fan.raw)
        .put("verticalLouver", s.verticalLouver).put("horizontalLouver", s.horizontalLouver)
        .put("eco", s.eco).put("powerful", s.powerful).put("converti", s.converti ?: 0).put("display", s.display)
        .put("nanoe", s.nanoe?.let { if (it) "on" else "off" } ?: "")
        .put("roomTemperature", s.roomTemperature ?: JSONObject.NULL)
        .put("isOnline", s.isOnline).put("firmware", s.firmware ?: "").put("updatedAt", s.updatedAt)
        .put("offTimer", s.offTimer ?: 0).put("onTimer", s.onTimer ?: 0)
        .put("sleepProfile", s.sleepProfile ?: "").put("sleepHour", s.sleepHour ?: -1)

    private fun decodeState(o: JSONObject): ACState {
        val fields = o.toMap()
        return ACState(
            isOn = o.optBoolean("isOn"),
            setpoint = o.optDouble("setpoint", 24.0),
            mode = ACMode.of(o.optString("mode")) ?: ACMode.COOL,
            fan = FanSpeed.of(o.optString("fan")) ?: FanSpeed.AUTO,
            verticalLouver = o.optInt("verticalLouver"),
            horizontalLouver = o.optInt("horizontalLouver"),
            eco = o.optBoolean("eco"),
            powerful = o.optBoolean("powerful"),
            converti = o.optInt("converti"),
            display = o.optBoolean("display", true),
            nanoe = when (o.optString("nanoe")) { "on" -> true; "off" -> false; else -> null },
            roomTemperature = ACState.double(fields["roomTemperature"]),
            isOnline = o.optBoolean("isOnline", true),
            firmware = o.optString("firmware").ifEmpty { null },
            offTimer = o.optLong("offTimer").takeIf { it > 0 },
            onTimer = o.optLong("onTimer").takeIf { it > 0 },
            sleepProfile = o.optString("sleepProfile").ifEmpty { null },
            sleepHour = o.optInt("sleepHour", -1).takeIf { it >= 0 },
            updatedAt = o.optLong("updatedAt"),
        )
    }
}

/**
 * The user's own sleep profiles, shared by every AC. Kept apart from [SharedStore] so they
 * stay after signing out: they hold nothing about the account.
 */
class ProfileStore(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("profiles", Context.MODE_PRIVATE)

    var sleepProfiles: List<SleepProfile>
        get() = runCatching {
            val json = JSONArray(prefs.getString("sleepProfiles", "[]"))
            (0 until json.length()).mapNotNull { json.optJSONObject(it) }.map { o ->
                val temperatures = o.getJSONArray("temperatures")
                SleepProfile(
                    o.getString("id"), o.getString("name"),
                    (0 until temperatures.length()).map { temperatures.getDouble(it) }, o.optBoolean("turnsOffAtEnd", true),
                )
            }
        }.getOrElse { emptyList() }
        set(value) = prefs.edit().putString("sleepProfiles", JSONArray(value.map {
            JSONObject().put("id", it.id).put("name", it.name).put("temperatures", JSONArray(it.temperatures))
                .put("turnsOffAtEnd", it.turnsOffAtEnd)
        }).toString()).apply()
}
