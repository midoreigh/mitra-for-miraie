// Adapted from Hawadaar (github.com/abdulghanitech/hawadaar), MIT License, © 2026 Abdul Ghani.
package com.midoreigh.mitra.miraie

import java.io.ByteArrayOutputStream

/**
 * Encoding and decoding for the subset of MQTT 3.1.1 that MirAIe needs:
 * CONNECT, SUBSCRIBE, PUBLISH (QoS 0), PINGREQ and DISCONNECT.
 */
object MqttPacket {
    val pingRequest = byteArrayOf(0xC0.toByte(), 0x00)
    val disconnect = byteArrayOf(0xE0.toByte(), 0x00)

    fun connect(clientId: String, username: String, password: String, keepAlive: Int): ByteArray {
        val body = ByteArrayOutputStream()
        body.write(string("MQTT"))
        body.write(byteArrayOf(0x04, 0xC2.toByte())) // protocol level 4; username + password + clean session
        body.write(byteArrayOf((keepAlive shr 8).toByte(), (keepAlive and 0xFF).toByte()))
        body.write(string(clientId))
        body.write(string(username))
        body.write(string(password))
        return packet(0x10, body.toByteArray())
    }

    fun subscribe(packetId: Int, topics: List<String>): ByteArray {
        val body = ByteArrayOutputStream()
        body.write(byteArrayOf((packetId shr 8).toByte(), (packetId and 0xFF).toByte()))
        for (topic in topics) {
            body.write(string(topic))
            body.write(0x00) // QoS 0
        }
        return packet(0x82, body.toByteArray())
    }

    fun publish(topic: String, payload: ByteArray): ByteArray = packet(0x30, string(topic) + payload)

    /** A packet received from the broker. */
    sealed interface Incoming {
        data class ConnAck(val returnCode: Int) : Incoming
        /**
         * [retained]: the broker is replaying the last message it kept for the topic, which may
         * be old, rather than passing on a new one.
         */
        class Publish(val topic: String, val payload: ByteArray, val retained: Boolean = false) : Incoming
        data object SubAck : Incoming
        data object PingResponse : Incoming
        data class Other(val type: Int) : Incoming
    }

    /** Reassembles packets from a TCP byte stream, which may split or merge them arbitrarily. */
    class Decoder {
        private var buffer = ByteArray(0)

        fun append(data: ByteArray): List<Incoming> {
            buffer += data
            val packets = mutableListOf<Incoming>()
            while (true) {
                val frame = nextFrame() ?: break
                packets += parse(frame.first, frame.second)
                buffer = buffer.copyOfRange(frame.third, buffer.size)
            }
            return packets
        }

        fun reset() {
            buffer = ByteArray(0)
        }

        private fun nextFrame(): Triple<Int, ByteArray, Int>? {
            if (buffer.size < 2) return null
            var length = 0
            var multiplier = 1
            var index = 1
            while (true) {
                if (index >= buffer.size || index > 4) return null
                val byte = buffer[index].toInt() and 0xFF
                length += (byte and 0x7F) * multiplier
                multiplier *= 128
                index++
                if (byte and 0x80 == 0) break
            }
            if (buffer.size < index + length) return null
            return Triple(buffer[0].toInt() and 0xFF, buffer.copyOfRange(index, index + length), index + length)
        }

        private fun parse(header: Int, body: ByteArray): Incoming = when (header shr 4) {
            2 -> Incoming.ConnAck(if (body.size >= 2) body[1].toInt() and 0xFF else 0xFF)
            3 -> {
                if (body.size < 2) {
                    Incoming.Other(3)
                } else {
                    val topicLength = (body[0].toInt() and 0xFF shl 8) or (body[1].toInt() and 0xFF)
                    if (body.size < 2 + topicLength) {
                        Incoming.Other(3)
                    } else {
                        val topic = String(body, 2, topicLength, Charsets.UTF_8)
                        val hasPacketId = (header shr 1) and 0x03 > 0
                        val start = minOf(body.size, 2 + topicLength + if (hasPacketId) 2 else 0)
                        Incoming.Publish(topic, body.copyOfRange(start, body.size), retained = header and 0x01 != 0)
                    }
                }
            }
            9 -> Incoming.SubAck
            13 -> Incoming.PingResponse
            else -> Incoming.Other(header shr 4)
        }
    }

    fun string(value: String): ByteArray {
        val bytes = value.toByteArray(Charsets.UTF_8)
        return byteArrayOf((bytes.size shr 8).toByte(), (bytes.size and 0xFF).toByte()) + bytes
    }

    fun packet(header: Int, body: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(header)
        var length = body.size
        do {
            var byte = length % 128
            length /= 128
            if (length > 0) byte = byte or 0x80
            out.write(byte)
        } while (length > 0)
        out.write(body)
        return out.toByteArray()
    }
}
