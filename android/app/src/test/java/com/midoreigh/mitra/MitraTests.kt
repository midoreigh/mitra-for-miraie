package com.midoreigh.mitra

import com.midoreigh.mitra.miraie.MirAIeApi
import com.midoreigh.mitra.miraie.MqttPacket
import com.midoreigh.mitra.model.ACCapabilities
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.model.ACMode
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.Louver
import com.midoreigh.mitra.model.SleepProfile
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MitraTests {
    @Test fun loginIdentifiers() {
        assertEquals(MirAIeApi.LoginIdentifier.Mobile("+919876543210"), MirAIeApi.loginIdentifier("98765 43210"))
        assertEquals(MirAIeApi.LoginIdentifier.Mobile("+919876543210"), MirAIeApi.loginIdentifier("09876543210"))
        assertEquals(MirAIeApi.LoginIdentifier.Mobile("+919876543210"), MirAIeApi.loginIdentifier("919876543210"))
        assertEquals(MirAIeApi.LoginIdentifier.Mobile("+447700900123"), MirAIeApi.loginIdentifier("+44 7700 900123"))
        assertEquals(MirAIeApi.LoginIdentifier.Email("a@b.co"), MirAIeApi.loginIdentifier(" a@b.co "))
        assertNull(MirAIeApi.loginIdentifier("98765"))
        assertNull(MirAIeApi.loginIdentifier("a@b"))
    }

    @Test fun packedRoomTemperature() {
        assertEquals(28.0 + 43.0 / 256, ACState.roomTemperature("43.28", "3.02")!!, 1e-9)
        // Some 3.02 units send a plain reading.
        assertEquals(26.5, ACState.roomTemperature("26.5", "3.02")!!, 1e-9)
        assertEquals(43.28, ACState.roomTemperature("43.28", "2.10")!!, 1e-9)
    }

    @Test fun statusFields() {
        val state = ACState().applying(
            mapOf("ps" to "on", "actmp" to "25.5", "acmd" to "dry", "acfs" to "high", "acvs" to 3, "achs" to "0", "cnv" to 70, "acng" to "on")
        )
        assertTrue(state.isOn)
        assertEquals(25.5, state.setpoint, 0.0)
        assertEquals(ACMode.DRY, state.mode)
        assertEquals(3, state.verticalLouver)
        assertEquals(Louver.SWING, state.horizontalLouver)
        assertEquals(70, state.converti)
        assertTrue(ACCapabilities().learning(state).nanoe)
    }

    @Test fun commandMessages() {
        val message = ACCommand.message(listOf(ACCommand.Temperature(24.4), ACCommand.Eco(true)))
        assertEquals(1, message["ki"])
        assertEquals("an", message["cnt"])
        assertEquals("26", message["actmp"]) // Eco sets 26 °C, as the MirAIe app does
        assertEquals("off", message["acpm"])
        assertEquals("24.5", ACCommand.format(24.4))
        assertEquals("16", ACCommand.format(3.0))
        val status = JSONObject("""{"actmp":"24","acmd":"cool"}""")
        assertTrue(ACCommand.isConfirmed(listOf(ACCommand.Temperature(24.0)), mapOf("actmp" to status.get("actmp"))))
        assertFalse(ACCommand.isConfirmed(listOf(ACCommand.Mode(ACMode.DRY)), mapOf("acmd" to "cool")))
    }

    @Test fun horizontalOrder() {
        assertEquals(listOf(1, 2, 3, 4, 5), listOf(2, 3, 1, 4, 5).map(Louver::horizontalSlot))
        assertEquals("Centre", Louver.horizontalLabel(1))
    }

    @Test fun mqttFraming() {
        val publish = MqttPacket.publish("a/status", """{"ps":"on"}""".toByteArray())
        val decoder = MqttPacket.Decoder()
        // Split across reads, then merged with a ping response.
        assertTrue(decoder.append(publish.copyOfRange(0, 3)).isEmpty())
        val packets = decoder.append(publish.copyOfRange(3, publish.size) + byteArrayOf(0xD0.toByte(), 0))
        assertEquals(2, packets.size)
        val incoming = packets[0] as MqttPacket.Incoming.Publish
        assertEquals("a/status", incoming.topic)
        assertEquals("""{"ps":"on"}""", String(incoming.payload))
        assertEquals(MqttPacket.Incoming.PingResponse, packets[1])
        assertFalse(incoming.retained)
    }

    /**
     * The broker replays the last status it kept when subscribing, even if the AC has since lost
     * power; the retain flag tells it apart from a fresh one.
     */
    @Test fun decodesRetainFlag() {
        val packet = MqttPacket.publish("a/status", "{}".toByteArray())
        packet[0] = (packet[0].toInt() or 0x01).toByte()
        val incoming = MqttPacket.Decoder().append(packet).single() as MqttPacket.Incoming.Publish
        assertEquals("a/status", incoming.topic)
        assertEquals("{}", String(incoming.payload))
        assertTrue(incoming.retained)
    }

    @Test fun sendsTimersAsMinutesFromNow() {
        val now = System.currentTimeMillis()
        val message = ACCommand.message(listOf(ACCommand.Timers(off = now + 4 * 3_600_000L, on = null)))
        assertEquals(14, message["ki"])
        val timers = message["actm"] as List<*>
        assertEquals(4 * 3600.0, (timers[0] as Int).toDouble(), 60.0)
        assertEquals(-1, timers[1])
        // To the minute: 20 s past the minute, 4 h later lands on the minute, 20 s short of 4 h.
        val minute = 1_800_000_000_000L - 1_800_000_000_000L % 60_000
        assertEquals(4 * 3600 - 20, ACCommand.seconds(until = minute + 4 * 3_600_000L, now = minute + 20_000))
        assertEquals(-1, ACCommand.seconds(null))
        assertEquals("[14400,-1]", JSONObject(mapOf("actm" to listOf(14400, -1))).getJSONArray("actm").toString())
    }

    @Test fun readsTimersAsTimes() {
        val status = JSONObject("""{"actm":[1793461838,-1]}""")
        val state = ACState().applying(mapOf("actm" to status.get("actm")))
        assertEquals(1_793_461_838_000L, state.offTimer)
        assertNull(state.onTimer)
        // Confirmed when the AC's time is within a couple of minutes of what was asked.
        val asked = ACCommand.Timers(off = 1_793_461_838_000L + 30_000, on = null)
        assertTrue(ACCommand.isConfirmed(listOf(asked), mapOf("actm" to status.get("actm"))))
        assertFalse(ACCommand.isConfirmed(listOf(asked.copy(on = 1_793_461_838_000L)), mapOf("actm" to status.get("actm"))))
    }

    @Test fun sendsSleepProfiles() {
        val profile = SleepProfile("abc123def0", "Night", listOf(26.0, 24.0, 27.0), turnsOffAtEnd = true)
        val message = ACCommand.message(listOf(ACCommand.StartSleep(profile)))
        assertEquals(12, message["ki"])
        assertEquals("on", message["acsp"])
        assertEquals("abc123def0", message["pid"])
        assertEquals(listOf("26.0", "24.0", "27.0", "00.0"), message["temps"])
        assertTrue(ACCommand.isConfirmed(listOf(ACCommand.StartSleep(profile)), mapOf("acsp" to "abc123def0")))
        val stop = ACCommand.message(listOf(ACCommand.StopSleep("abc123def0", profile.wireTemperatures)))
        assertEquals("off", stop["acsp"])
        assertTrue(ACCommand.isConfirmed(listOf(ACCommand.StopSleep("abc123def0", emptyList())), mapOf("acsp" to "none")))
        assertEquals(10, SleepProfile.newId().length)
    }

    @Test fun readsSleepStatus() {
        val running = ACState().applying(mapOf("acsp" to "abc123def0", "sleep_indx" to "1"))
        assertEquals("abc123def0", running.sleepProfile)
        assertEquals(1, running.sleepHour)
        val stopped = running.applying(mapOf("acsp" to "none"))
        assertNull(stopped.sleepProfile)
        assertNull(stopped.sleepHour)
        // Started locally: the first hour's temperature is set at once.
        val started = ACState(setpoint = 22.0).applying(ACCommand.StartSleep(SleepProfile(name = "Night", temperatures = listOf(26.0), turnsOffAtEnd = false)))
        assertEquals(26.0, started.setpoint, 0.0)
        assertEquals(0, started.sleepHour)
    }

    @Test fun gentleFollowsTheSetTemperature() {
        assertEquals(listOf(22.0, 22.0, 22.0, 23.0, 23.0, 23.0, 24.0, 24.0), SleepProfile.GENTLE.schedule(from = 22.0))
        assertEquals(listOf("24.0", "24.0", "24.0", "25.0", "25.0", "25.0", "26.0", "26.0", "00.0"), SleepProfile.GENTLE.wireTemperatures)
        assertEquals("default", SleepProfile.GENTLE.id)
    }
}
