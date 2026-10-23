import Foundation
import XCTest
import MIDI2
import SingVoice
@testable import SingMIDI2

final class SingMIDI2Tests: XCTestCase {
    private func phrase() throws -> PhraseDocument {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("examples/three-syllables.json"))
        return try JSONDecoder().decode(PhraseDocument.self, from: data)
    }

    func testTypedUniversalPacketRoundTrip() throws {
        let events = try SingMIDI2Score.compile(phrase())
        XCTAssertEqual(events.count, 6)
        XCTAssertEqual(events.map(\.atMilliseconds), [0, 400, 440, 940, 980, 1480])
        XCTAssertTrue(events.allSatisfy { (($0.packet.word0 >> 28) & 0xf) == 4 })
        XCTAssertNotNil(Midi2NoteOn(ump: events[0].packet))
        XCTAssertEqual(Midi2NoteOn(ump: events[0].packet)?.note.rawValue, 62)
        XCTAssertEqual(Midi2ChannelVoiceBody(ump: events[1].packet)?.status, 8)
        XCTAssertEqual(Midi2ChannelVoiceBody(ump: events[2].packet)?.status, 9)
        let result = try SingMIDI2Score.decode(phrase(), events: events)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.syllableId), ["s1", "s2", "s3"])
        XCTAssertEqual(result.map(\.pitch), [62, 65, 64])
    }

    func testMIDI2PacketsDriveSamePCMAsOriginalAuthoring() throws {
        let original = try phrase()
        let baseline = try ProceduralSinger.render(original)
        let midiDriven = try SingMIDI2Score.rehearse(original, events: SingMIDI2Score.compile(original))
        XCTAssertEqual(baseline.samples, midiDriven.samples)
        XCTAssertEqual(midiDriven.samples.count, 75_120)
        XCTAssertGreaterThan(midiDriven.rms, 0.01)
    }

    func testRealPerNotePressureChangesRenderedAmplitude() throws {
        let original = try phrase()
        let events = try SingMIDI2Score.compile(original)
        let baseline = try SingMIDI2Score.rehearse(original, events: events)
        var expressive = events
        expressive.append(try SingMIDI2Score.notePressure(pitch: 65, atMilliseconds: 650, value: 0))
        expressive.sort { $0.atMilliseconds < $1.atMilliseconds }
        let performance = try SingMIDI2Score.decode(original, events: expressive)
        XCTAssertEqual(performance[1].pressurePoints.count, 1)
        let performed = try SingMIDI2Score.rehearse(original, events: expressive)
        XCTAssertNotEqual(performed.samples, baseline.samples)
        // Peak normalization is global, so compare within-note early and late RMS ratios.
        func windowRMS(_ frames: [Float], start: Int, end: Int) -> Double {
            let values = frames[start..<end]
            return sqrt(values.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(values.count))
        }
        let before = windowRMS(performed.samples, start: 48_000 * 500 / 1000, end: 48_000 * 550 / 1000)
        let after = windowRMS(performed.samples, start: 48_000 * 770 / 1000, end: 48_000 * 820 / 1000)
        XCTAssertLessThan(after / before, 0.75)
    }

    func testUnmatchedAndMalformedPacketsRejected() throws {
        let doc = try phrase()
        let full = try SingMIDI2Score.compile(doc)
        XCTAssertThrowsError(try SingMIDI2Score.decode(doc, events: Array(full.dropLast())))
        XCTAssertThrowsError(try SingMIDI2Score.decode(doc, events: [full[1]] + full))
        XCTAssertThrowsError(try SingMIDI2Score.decode(doc, events: [full[1], full[0]]))
        XCTAssertThrowsError(try SingMIDI2Score.decode(doc, events: [
            TimedSingPacket(atMilliseconds: 0,
                packet: UmpPacket64(word0: 0x20903e00, word1: 0))] + full))
        XCTAssertThrowsError(try SingMIDI2Score.decode(doc, events: [
            TimedSingPacket(atMilliseconds: 0,
                packet: UmpPacket64(word0: full[0].packet.word0 | 0x01000000,
                                    word1: full[0].packet.word1))] + Array(full.dropFirst())))
    }

    func testNoCoreMIDIImportInOurInstrumentSources() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let files = [
            "Sources/SingVoice/SingVoice.swift",
            "Sources/SingMIDI2/SingMIDI2.swift",
            "Sources/sing-midi2-rehearsal/main.swift",
            "Package.swift"
        ]
        for file in files {
            let source = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            XCTAssertFalse(source.contains("import " + "CoreMIDI"), "\(file) imports the rejected API")
            XCTAssertFalse(source.contains("import " + "AudioToolbox"), "\(file) imports a host audio framework")
            XCTAssertFalse(source.contains(".product(name: " + "\"TeatroAppleBridge\""), "\(file) depends on an Apple bridge")
        }
        let host = try String(contentsOf: root.appendingPathComponent(
            "Sources/sing-macos-output/main.swift"), encoding: .utf8)
        XCTAssertFalse(host.contains("import " + "CoreMIDI"))
        XCTAssertFalse(host.contains("MIDI" + "OutputPortCreate"))
        XCTAssertTrue(host.contains("import AVFoundation"))
    }

    func testSampleAccurateBufferSizesProduceIdenticalPCM() throws {
        let doc = try phrase()
        let packets = try SingMIDI2Score.compile(doc)
        let prepared = try SingMIDI2Score.prepareRealtime(doc, events: packets)
        XCTAssertEqual(prepared.eventCount, 6)
        let small = RealtimeSinger(prepared: prepared)
        let a = small.renderOffline(blockFrames: 37)
        let large = RealtimeSinger(prepared: prepared)
        let b = large.renderOffline(blockFrames: 1024)
        XCTAssertEqual(a.samples, b.samples)
        XCTAssertTrue(a.samples.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(a.rms, 0.001)
        XCTAssertEqual(small.articulationsStarted, 3)
        XCTAssertTrue(small.isFinished)
        small.reset()
        let restarted = small.renderOffline(blockFrames: 256)
        XCTAssertEqual(restarted.samples, a.samples)
    }

    func testMelismaRetainsOriginalVowelAcrossPitchChange() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let fixture = try Data(contentsOf: root.appendingPathComponent("examples/three-syllables.json"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
        var performance = try XCTUnwrap(json["performance"] as? [String: Any])
        var notes = try XCTUnwrap(performance["notes"] as? [[String: Any]])
        notes.insert([
            "id": "n1b", "syllableId": "s1", "pitch": 69,
            "onMs": 410, "offMs": 435, "velocity16": 30_000,
            "advanceSyllable": false
        ], at: 1)
        performance["notes"] = notes
        json["performance"] = performance
        let doc = try JSONDecoder().decode(PhraseDocument.self,
            from: JSONSerialization.data(withJSONObject: json))
        let packets = try SingMIDI2Score.compile(doc)
        XCTAssertEqual(packets.count, 8)
        let prepared = try SingMIDI2Score.prepareRealtime(doc, events: packets)
        let voice = RealtimeSinger(prepared: prepared)
        let rendered = voice.renderOffline(blockFrames: 128)
        XCTAssertEqual(voice.articulationsStarted, 3)
        XCTAssertTrue(rendered.samples.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(rendered.rms, 0.001)
    }

    func testRealtimePressureChangesOutputWithoutChangingScore() throws {
        let doc = try phrase()
        let events = try SingMIDI2Score.compile(doc)
        var pressure = events
        pressure.append(try SingMIDI2Score.notePressure(pitch: 65,
            atMilliseconds: 650, value: 0))
        pressure.sort { $0.atMilliseconds < $1.atMilliseconds }
        let baseline = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: events))
            .renderOffline(blockFrames: 64)
        let expressive = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: pressure))
            .renderOffline(blockFrames: 64)
        XCTAssertNotEqual(baseline.samples, expressive.samples)
        XCTAssertGreaterThan(baseline.rms, expressive.rms)
    }

    func testRealtimeReleaseIsQuietAndDerivativeBounded() throws {
        let doc = try phrase()
        let packets = try SingMIDI2Score.compile(doc)
        let voice = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: packets))
        let sound = voice.renderOffline(blockFrames: 511)
        XCTAssertEqual(sound.samples.count, 90_240)
        let tail = sound.samples.suffix(4_800)
        let tailRMS = sqrt(tail.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(tail.count))
        XCTAssertLessThan(tailRMS, 0.003)
        var largestStep = 0.0
        for frame in 1..<sound.samples.count {
            largestStep = max(largestStep,
                abs(Double(sound.samples[frame]) - Double(sound.samples[frame - 1])))
        }
        XCTAssertLessThan(largestStep, 0.15)
    }

    func testNoExternalTransportAndAuthenticPressurePacket() throws {
        let event = try SingMIDI2Score.notePressure(pitch: 65, atMilliseconds: 650, value: UInt32.max)
        let words = event.packet.words
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual((words[0] >> 20) & 0xf, 0xa)
        XCTAssertEqual(words[1], UInt32.max)
        XCTAssertThrowsError(try SingMIDI2Score.notePressure(pitch: 128, atMilliseconds: 650, value: 0))
    }
}
