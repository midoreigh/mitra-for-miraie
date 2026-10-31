import Foundation
import Testing
@testable import MitraKit

@Suite struct ACStateTests {
    @Test func decodesStatusMessage() {
        let state = ACState(fields: ["ps": "on", "actmp": "24.5", "acmd": "cool", "acfs": "high",
                                     "acvs": 3, "achs": "0", "acem": "off", "acpm": "on",
                                     "acdc": "off", "rssi": -62, "onlineStatus": "true"])
        #expect(state.isOn)
        #expect(state.setpoint == 24.5)
        #expect(state.mode == .cool)
        #expect(state.fan == .high)
        #expect(state.verticalLouver == 3)
        #expect(state.horizontalLouver == Louver.swing)
        #expect(state.powerful && !state.eco && !state.display)
        #expect(state.wifiSignal == -62)
    }

    @Test func ordersHorizontalLouverFromTheLeft() {
        #expect(Louver.horizontalLeftToRight.map(Louver.horizontalSlot) == [1, 2, 3, 4, 5])
        #expect(Louver.horizontalSlot(1) == 3) // MirAIe's 1 points straight ahead
    }

    @Test func decodesPackedRoomTemperature() {
        let state = ACState(fields: ["V": "3.02", "rmtmp": "43.28"])
        #expect(abs((state.roomTemperature ?? 0) - (28 + 43.0 / 256)) < 0.001)
        #expect(ACState(fields: ["V": "2.10", "rmtmp": "27"]).roomTemperature == 27)
        #expect(ACState(fields: ["V": "3.02", "rmtmp": "26.5"]).roomTemperature == 26.5)
    }

    @Test func partialUpdatesKeepOtherFields() {
        var state = ACState(fields: ["ps": "on", "acmd": "heat"])
        state.apply(["acfs": "low"])
        #expect(state.isOn && state.mode == .heat && state.fan == .low)
    }
}

@Suite struct ACCommandTests {
    @Test func payloadCombinesCommands() throws {
        let data = ACCommand.payload([.power(true), .temperature(22), .horizontalLouver(4)])
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["ps"] as? String == "on")
        #expect(json["actmp"] as? String == "22")
        #expect(json["achs"] as? Int == 4)
        #expect(json["cnt"] as? String == "an")
    }

    @Test func clampsValues() {
        #expect(ACCommand.temperature(40).fields["actmp"] as? String == "30")
        #expect(ACCommand.temperature(23.5).fields["actmp"] as? String == "23.5")
        #expect(ACCommand.verticalLouver(9).fields["acvs"] as? Int == 5)
    }

    @Test func confirmsMatchingStatus() {
        #expect(ACCommand.isConfirmed([.temperature(24), .power(true)], by: ["actmp": "24.0", "ps": "on"]))
        #expect(!ACCommand.isConfirmed([.temperature(24)], by: ["actmp": "25"]))
        #expect(!ACCommand.isConfirmed([.mode(.cool)], by: ["ps": "on"]))
    }

    @Test func sendsTimersAsMinutesFromNow() throws {
        let off = Date().addingTimeInterval(4 * 3600)
        let data = ACCommand.payload([.timers(off: off, on: nil)])
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let timers = try #require(json["actm"] as? [Int])
        #expect(abs(timers[0] - 4 * 3600) <= 30)
        #expect(timers[1] == -1)
        #expect(json["ki"] as? Int == 14)
    }

    @Test func readsTimersAsTimes() {
        let state = ACState(fields: ["actm": [1793461838, -1]])
        #expect(state.offTimer == Date(timeIntervalSince1970: 1793461838))
        #expect(state.onTimer == nil)
        #expect(ACCommand.isConfirmed([.timers(off: Date(timeIntervalSince1970: 1793461800), on: nil)],
                                      by: ["actm": [1793461838, -1]]))
        #expect(!ACCommand.isConfirmed([.timers(off: nil, on: nil)], by: ["actm": [1793461838, -1]]))
    }

    @Test func sendsSleepProfiles() throws {
        let profile = SleepProfile(id: "a201719138", name: "Night", temperatures: [28, 27, 24], turnsOffAtEnd: true)
        let json = try #require(try JSONSerialization.jsonObject(with: ACCommand.payload([.startSleep(profile)])) as? [String: Any])
        #expect(json["acsp"] as? String == "on")
        #expect(json["pid"] as? String == "a201719138")
        #expect(json["temps"] as? [String] == ["28.0", "27.0", "24.0", "00.0"])
        #expect(json["ki"] as? Int == 12)

        let running = ACState(fields: ["acsp": "a201719138", "sleep_indx": "1"])
        #expect(running.sleepProfile == "a201719138" && running.sleepHour == 1)
        #expect(ACCommand.isConfirmed([.startSleep(profile)], by: ["acsp": "a201719138"]))
        #expect(ACState(fields: ["acsp": "none"]).sleepProfile == nil)
    }

    @Test func gentleFollowsTheSetTemperature() {
        #expect(SleepProfile.gentle.schedule(from: 25) == [25, 25, 25, 26, 26, 26, 27, 27])
    }
}

@Suite struct LoginIdentifierTests {
    @Test func parsesIndianMobileNumbers() {
        #expect(MirAIeAPI.loginIdentifier(for: "98765 43210") == .mobile("+919876543210"))
        #expect(MirAIeAPI.loginIdentifier(for: "098765 43210") == .mobile("+919876543210"))
        #expect(MirAIeAPI.loginIdentifier(for: "me@example.com") == .email("me@example.com"))
        #expect(MirAIeAPI.loginIdentifier(for: "123") == nil)
    }
}

@Suite struct MQTTPacketTests {
    @Test func decodesSplitPublish() {
        let packet = MQTTPacket.publish(topic: "a/status", payload: Data("{}".utf8))
        var decoder = MQTTPacket.Decoder()
        #expect(decoder.append(packet.prefix(3)).isEmpty)
        #expect(decoder.append(packet.dropFirst(3)) == [.publish(topic: "a/status", payload: Data("{}".utf8))])
    }

    /// The broker replays the last status it kept when subscribing, even if the AC has since lost
    /// power; the retain flag tells it apart from a fresh one.
    @Test func decodesRetainFlag() {
        var packet = MQTTPacket.publish(topic: "a/status", payload: Data("{}".utf8))
        packet[packet.startIndex] |= 0x01
        var decoder = MQTTPacket.Decoder()
        #expect(decoder.append(packet) == [.publish(topic: "a/status", payload: Data("{}".utf8), retained: true)])
    }
}
