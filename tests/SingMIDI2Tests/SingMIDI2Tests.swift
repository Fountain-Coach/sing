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
