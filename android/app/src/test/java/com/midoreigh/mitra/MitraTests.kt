package com.midoreigh.mitra

import com.midoreigh.mitra.miraie.MirAIeApi
import com.midoreigh.mitra.miraie.MqttPacket
import com.midoreigh.mitra.model.ACCapabilities
import com.midoreigh.mitra.model.ACCommand
import com.midoreigh.mitra.model.ACMode
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.model.Louver
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
    }
}
