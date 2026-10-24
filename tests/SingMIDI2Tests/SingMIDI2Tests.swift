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
            "Sources/SingVoice/RealtimeSinger.swift",
            "Sources/SingMIDI2/SingMIDI2.swift",
            "Sources/SingMIDI2/SyntheticRehearsal.swift",
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

    func testMIDI2PitchAndBreathUseRealTypedPackets() throws {
        let baseline = try SingMIDI2Score.compile(phrase())
        let bend = try SingMIDI2Score.pitchBend(semitones: 1.25, atMilliseconds: 610)
        let air = try SingMIDI2Score.breath(normalized: 0.65, atMilliseconds: 620)
        XCTAssertEqual(Midi2ChannelVoiceBody(ump: bend.packet)?.status, 0xE)
        XCTAssertEqual(Midi2ChannelVoiceBody(ump: air.packet)?.status, 0xB)
        XCTAssertEqual(ControlChange(ump: Ump64(word0: air.packet.word0, word1: air.packet.word1)!)?.control.rawValue, 2)
        var events = baseline + [bend, air]
        events.sort { $0.atMilliseconds < $1.atMilliseconds }
        let notes = try SingMIDI2Score.decode(phrase(), events: events)
        XCTAssertEqual(notes[1].pitchPoints.count, 1)
        XCTAssertEqual(notes[1].breathPoints.count, 1)
        XCTAssertEqual(notes[1].pitchPoints[0].semitones, 1.25, accuracy: 0.00001)
        XCTAssertEqual(notes[1].breathPoints[0].normalized, 0.65, accuracy: 0.00001)
        XCTAssertThrowsError(try SingMIDI2Score.pitchBend(semitones: 2.01, atMilliseconds: 1))
        XCTAssertThrowsError(try SingMIDI2Score.pitchBend(semitones: .nan, atMilliseconds: 1))
        XCTAssertThrowsError(try SingMIDI2Score.breath(normalized: 1.01, atMilliseconds: 1))
        XCTAssertThrowsError(try SingMIDI2Score.breath(normalized: .infinity, atMilliseconds: 1))
        XCTAssertThrowsError(try SingMIDI2Score.breath(normalized: 0.1, atMilliseconds: -1))
        let unsupported = ControlChange(group: Uint4(0)!, channel: Uint4(0)!,
                                        control: Uint7(3)!, value: UInt32.max).ump()
        events = baseline + [TimedSingPacket(atMilliseconds: 600,
                       packet: UmpPacket64(word0: unsupported.word0, word1: unsupported.word1))]
        events.sort { $0.atMilliseconds < $1.atMilliseconds }
        XCTAssertThrowsError(try SingMIDI2Score.decode(phrase(), events: events))
    }

    func testBentPitchChangesFundamentalWithoutMovingFormantBanks() throws {
        let doc = try phrase()
        let raw = try SingMIDI2Score.compile(doc)
        var bent = raw
        bent.append(try SingMIDI2Score.pitchBend(semitones: 1.0, atMilliseconds: 600))
        bent.sort { $0.atMilliseconds < $1.atMilliseconds }
        let unchanged = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: raw))
        let changed = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: bent))
        var segment = [Float](repeating: 0, count: 48_000 * 810 / 1000)
        segment.withUnsafeMutableBufferPointer { unchanged.render(into: $0) }
        segment.withUnsafeMutableBufferPointer { changed.render(into: $0) }
        let ratio = changed.currentFundamentalHz / unchanged.currentFundamentalHz
        XCTAssertEqual(ratio, pow(2.0, 1.0 / 12.0), accuracy: 0.003)
        XCTAssertEqual(unchanged.articulationsStarted, changed.articulationsStarted)
    }

    func testBreathIsDeterministicAndNotJustAnotherVolumeChange() throws {
        let doc = try phrase()
        let source = try SingMIDI2Score.compile(doc)
        var breathy = source
        breathy.append(try SingMIDI2Score.breath(normalized: 0.85, atMilliseconds: 600))
        breathy.sort { $0.atMilliseconds < $1.atMilliseconds }
        let plain = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: source))
            .renderOffline(blockFrames: 33)
        let first = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: breathy))
            .renderOffline(blockFrames: 37)
        let second = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: breathy))
            .renderOffline(blockFrames: 511)
        XCTAssertEqual(first.samples, second.samples)
        let start = 48_000 * 700 / 1000
        let end = 48_000 * 850 / 1000
        var differenceSquared = 0.0
        for i in start..<end {
            let delta = Double(first.samples[i]) - Double(plain.samples[i])
            differenceSquared += delta * delta
        }
        let differenceRMS = sqrt(differenceSquared / Double(end - start))
        XCTAssertGreaterThan(differenceRMS, 0.005)
        XCTAssertTrue(first.samples.allSatisfy(\.isFinite))
    }

    func testOptionalVibratoIsDeterministicAndIndependentOfPitchBend() throws {
        let doc = try phrase()
        var events = try SingMIDI2Score.compile(doc)
        events.append(try SingMIDI2Score.pitchBend(semitones: -0.5, atMilliseconds: 600))
        events.sort { $0.atMilliseconds < $1.atMilliseconds }
        let flat = RealtimeSinger(prepared: try SingMIDI2Score.prepareRealtime(doc, events: events))
            .renderOffline(blockFrames: 128)
        let prepared = try SingMIDI2Score.prepareRealtime(doc, events: events, vibratoCents: 24)
        let a = RealtimeSinger(prepared: prepared).renderOffline(blockFrames: 37)
        let b = RealtimeSinger(prepared: prepared).renderOffline(blockFrames: 1024)
        XCTAssertEqual(a.samples, b.samples)
        XCTAssertNotEqual(a.samples, flat.samples)
        XCTAssertThrowsError(try SingMIDI2Score.prepareRealtime(doc, events: events, vibratoCents: 51))
    }

    func testLongFourNoteMelismaScenarioWithBreathAndBend() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let input = try Data(contentsOf: root.appendingPathComponent("examples/sustained-melisma.json"))
        let doc = try JSONDecoder().decode(PhraseDocument.self, from: input)
        let base = try SingMIDI2Score.compile(doc)
        let melisma = doc.performance.notes[1]
        XCTAssertFalse(melisma.advanceSyllable)
        let events = try SyntheticSingRehearsal.expressed(doc, startingFrom: base)
        let plan = try SingMIDI2Score.prepareRealtime(doc, events: events, vibratoCents: 24)
        XCTAssertEqual(plan.noteCount, 4)
        XCTAssertEqual(plan.eventCount, 12)
        let singer = RealtimeSinger(prepared: plan)
        let pcm = singer.renderOffline(blockFrames: 97)
        XCTAssertEqual(pcm.samples.count, 249_600)
        XCTAssertEqual(singer.articulationsStarted, 3)
        XCTAssertTrue(pcm.samples.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(pcm.rms, 0.01)
        XCTAssertLessThan(pcm.peak, 0.95)
    }

    func testMalformedReservedMIDI2FieldsAndCapacityFailClosed() throws {
        let doc = try phrase()
        let base = try SingMIDI2Score.compile(doc)
        let bend = try SingMIDI2Score.pitchBend(semitones: 1, atMilliseconds: 610)
        let breath = try SingMIDI2Score.breath(normalized: 0.4, atMilliseconds: 620)
        let pressure = try SingMIDI2Score.notePressure(pitch: 65,
                                                       atMilliseconds: 630, value: UInt32.max / 2)
        for message in [bend, breath, pressure] {
            let corrupt = TimedSingPacket(atMilliseconds: message.atMilliseconds,
                packet: UmpPacket64(word0: message.packet.word0 | 1,
                                    word1: message.packet.word1))
            var packets = base + [corrupt]
            packets.sort { $0.atMilliseconds < $1.atMilliseconds }
            XCTAssertThrowsError(try SingMIDI2Score.decode(doc, events: packets))
        }
        let oversized = Array(repeating: base[0], count: 16_385)
        XCTAssertThrowsError(try SingMIDI2Score.decode(doc, events: oversized))
    }

    func testPlainArticulatedExpressiveSameScoreThreeDifferentPCM() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let input = try Data(contentsOf: root.appendingPathComponent("examples/sustained-melisma.json"))
        let doc = try JSONDecoder().decode(PhraseDocument.self, from: input)
        let base = try SingMIDI2Score.compile(doc)
        let gesture = try SyntheticSingRehearsal.expressed(doc, startingFrom: base)
        let plain = try SingMIDI2Score.prepareRealtime(doc, events: base)
        let articulated = try SingMIDI2Score.prepareRealtime(
            doc, events: base, articulation: .articulated)
        let expressive = try SingMIDI2Score.prepareRealtime(
            doc, events: gesture, vibratoCents: 24, articulation: .articulated)
        let plainPCM = RealtimeSinger(prepared: plain).renderOffline(blockFrames: 37)
        let articulatedPCM = RealtimeSinger(prepared: articulated).renderOffline(blockFrames: 251)
        let expressivePCM = RealtimeSinger(prepared: expressive).renderOffline(blockFrames: 1024)
        XCTAssertEqual(plainPCM.samples.count, 249_600)
        XCTAssertEqual(articulatedPCM.samples.count, plainPCM.samples.count)
        XCTAssertEqual(expressivePCM.samples.count, plainPCM.samples.count)
        XCTAssertNotEqual(plainPCM.samples, articulatedPCM.samples)
        XCTAssertNotEqual(articulatedPCM.samples, expressivePCM.samples)
        XCTAssertGreaterThan(articulatedPCM.rms, 0.01)
        XCTAssertGreaterThan(expressivePCM.rms, 0.01)
        let repeated = RealtimeSinger(prepared: expressive).renderOffline(blockFrames: 47)
        XCTAssertEqual(expressivePCM.samples, repeated.samples)
        func onsetDifference(_ left: [Float], _ right: [Float], start: Int, end: Int) -> Double {
            let values = (start..<end).map { Double(left[$0] - right[$0]) }
            return sqrt(values.reduce(0.0) { $0 + $1 * $1 } / Double(values.count))
        }
        // Audition alteration must affect the phoneme onset, not just a file metadata flag.
        XCTAssertGreaterThan(onsetDifference(plainPCM.samples, articulatedPCM.samples,
                                             start: 48_000 * 2150 / 1000,
                                             end: 48_000 * 2300 / 1000), 0.01)
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
