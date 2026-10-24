import Foundation
import XCTest
import SingVoice
import SingMIDI2
import SingSpeechExperiment
import CryptoKit

final class SingSpeechExperimentTests: XCTestCase {
    private var scoreURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("examples/sustained-melisma.json")
    }

    private func scoreAndNotes() throws -> (PhraseDocument, [SingPerformanceNote]) {
        let source = try JSONDecoder().decode(PhraseDocument.self, from: Data(contentsOf: scoreURL))
        let events = try SingMIDI2Score.compile(source)
        return (source, try SingMIDI2Score.decode(source, events: events))
    }

    private func fixture() -> (DecodedSpeechWav, SpeechSourceManifest) {
        let rate = 48_000
        var samples = [Float]()
        var regions = [SpeechSourceManifest.Region]()
        for (index, frequency) in [177.0, 203.0, 220.0].enumerated() {
            let start = samples.count
            let onset = Int(0.08 * Double(rate))
            let sustain = Int(0.58 * Double(rate))
            for i in 0..<onset {
                let t = Double(i) / Double(rate)
                samples.append(Float(0.10 * sin(2 * .pi * frequency * t)))
            }
            let vowelStart = samples.count
            for i in 0..<sustain {
                let t = Double(i) / Double(rate)
                samples.append(Float(0.24 * sin(2 * .pi * frequency * t) +
                                     0.09 * sin(4 * .pi * frequency * t)))
            }
            regions.append(.init(syllableId: "s\(index + 1)", onsetStartFrame: start,
                                 vowelStartFrame: vowelStart, vowelEndFrame: samples.count))
            samples += [Float](repeating: 0, count: rate / 8)
        }
        let digest = String(repeating: "a", count: 64)
        let wav = DecodedSpeechWav(sampleRate: rate, samples: samples, sha256: digest)
        let manifest = SpeechSourceManifest(
            sourceKind: "synthetic-test-only", sourceModelOrVoice: "unit-test",
            sourceText: "la mi na", sampleRate: rate, sourceWavSHA256: digest,
            rightsDeclaration: "original synthetic unit test; no human voice",
            alignmentStatus: "provisional", regions: regions
        )
        return (wav, manifest)
    }

    func testSyntheticSourceHasExpectedFundamental() {
        let (wav, manifest) = fixture()
        let region = manifest.regions[0]
        let samples = Array(wav.samples[region.vowelStartFrame..<region.vowelEndFrame])
        let result = SpeechPitch.estimate(samples, sampleRate: wav.sampleRate)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.hz, 177, accuracy: 5)
        XCTAssertGreaterThan(result!.confidence, 0.80)
    }

    func testPrivateHybridRendererUsesFourNotesAndThreeOnsets() throws {
        let (document, notes) = try scoreAndNotes()
        let (wav, manifest) = fixture()
        let (speechTake, result) = try PrivateSpeechSinger.render(
            document: document, performedNotes: notes, speech: wav, manifest: manifest)
        XCTAssertEqual(speechTake.sampleRate, 48_000)
        XCTAssertEqual(speechTake.samples.count, Int(5.2 * 48_000))
        XCTAssertGreaterThan(speechTake.rms, 0.001)
        XCTAssertLessThan(speechTake.peak, 0.851)
        XCTAssertEqual(result.syllables.map(\.id), ["s1", "s2", "s3"])
        XCTAssertEqual(result.syllables.map(\.outputOnsetCount), [1, 1, 1])
        XCTAssertEqual(result.phonemeRecognition, "not-performed")
        XCTAssertEqual(result.publicRelease, "not-admitted")
        XCTAssertFalse(result.coreMIDI)
        let first = SpeechPitch.estimate(
            Array(speechTake.samples[(48_000 / 2)..<(48_000 * 3 / 4)]),
            sampleRate: 48_000)
        let melisma = SpeechPitch.estimate(
            Array(speechTake.samples[(48_000 * 3 / 2)..<(48_000 * 7 / 4)]),
            sampleRate: 48_000)
        XCTAssertNotNil(first)
        XCTAssertNotNil(melisma)
        XCTAssertEqual(first!.hz, 261.6, accuracy: 25)
        XCTAssertEqual(melisma!.hz, 329.6, accuracy: 25)
        let proceduralPlan = try SingMIDI2Score.prepareRealtime(
            document, events: SingMIDI2Score.compile(document),
            articulation: .articulated)
        let proceduralTake = RealtimeSinger(prepared: proceduralPlan).renderOffline()
        XCTAssertEqual(proceduralTake.samples.count, speechTake.samples.count)
        XCTAssertNotEqual(proceduralTake.samples, speechTake.samples)
        // Determinism independent of output audio block boundaries.
        let (again, _) = try PrivateSpeechSinger.render(
            document: document, performedNotes: notes, speech: wav, manifest: manifest)
        XCTAssertEqual(again.samples, speechTake.samples)
    }

    func testNaturalPreludeRequiresExplicitChangeAndRetainsOriginalDefault() throws {
        let (document, notes) = try scoreAndNotes()
        let (source, manifest) = fixture()
        let (unchanged, defaultReceipt) = try PrivateSpeechSinger.render(
            document: document, performedNotes: notes,
            speech: source, manifest: manifest)
        let (zero, _) = try PrivateSpeechSinger.render(
            document: document, performedNotes: notes,
            speech: source, manifest: manifest, naturalPreludeMilliseconds: 0)
        let (extended, extendedReceipt) = try PrivateSpeechSinger.render(
            document: document, performedNotes: notes,
            speech: source, manifest: manifest, naturalPreludeMilliseconds: 230)
        XCTAssertEqual(defaultReceipt.naturalPreludeMilliseconds, 0)
        XCTAssertEqual(extendedReceipt.naturalPreludeMilliseconds, 230)
        XCTAssertEqual(unchanged.samples, zero.samples)
        XCTAssertNotEqual(unchanged.samples, extended.samples)
        XCTAssertEqual(unchanged.samples.count, extended.samples.count)
        XCTAssertEqual(extendedReceipt.syllables.map(\.outputOnsetCount), [1, 1, 1])
        for invalid in [-1, 49, 321] {
            XCTAssertThrowsError(try PrivateSpeechSinger.render(
                document: document, performedNotes: notes,
                speech: source, manifest: manifest, naturalPreludeMilliseconds: invalid))
        }
    }

    func testRejectsUnidentifiedSourceAndMissingPulse() throws {
        let (document, notes) = try scoreAndNotes()
        let (wav, _) = fixture()
        let bad = SpeechSourceManifest(
            sourceKind: "synthetic-test-only", sourceModelOrVoice: "fixture",
            sourceText: "la mi na", sampleRate: 48_000,
            sourceWavSHA256: String(repeating: "0", count: 64),
            rightsDeclaration: "private test", alignmentStatus: "provisional",
            regions: [])
        XCTAssertThrowsError(try PrivateSpeechSinger.render(
            document: document, performedNotes: notes, speech: wav, manifest: bad))
        var noise = [Float](repeating: 0, count: 48_000)
        var state: UInt32 = 12345
        for i in noise.indices {
            state = 1664525 &* state &+ 1013904223
            noise[i] = Float(Double(state) / Double(UInt32.max) * 2 - 1) * 0.1
        }
        XCTAssertNil(SpeechPitch.estimate(noise, sampleRate: 48_000))
    }

    func testReaderRejectsWrongHashWithoutDisclosingAudio() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        try Data("not-a-WAV".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try PrivateSpeechWav.read(
            url: url, expectedSHA256: String(repeating: "0", count: 64)))
        let matchingHash = SHA256.hash(data: try Data(contentsOf: url))
            .map { String(format: "%02x", $0) }.joined()
        XCTAssertThrowsError(try PrivateSpeechWav.read(
            url: url, expectedSHA256: matchingHash))
    }
}
