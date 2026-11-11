import Foundation
import XCTest
@testable import SingVoice

final class SingFricativeTests: XCTestCase {
    private func fixture() throws -> PhraseDocument {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let input = try Data(contentsOf: root.appendingPathComponent("examples/air-syllables.json"))
        return try JSONDecoder().decode(PhraseDocument.self, from: input)
    }

    private func prepared(_ document: PhraseDocument) throws -> RealtimePreparedPhrase {
        let notes = document.performance.notes.map {
            SingPerformanceNote(id: $0.id, syllableId: $0.syllableId, pitch: $0.pitch,
                                onMs: $0.onMs, offMs: $0.offMs, velocity16: $0.velocity16)
        }
        return try RealtimePreparedPhrase(document: document, notes: notes, articulation: .articulated)
    }

    func testFricativeVocabularyProvidesAudibleBoundedOfflinePCM() throws {
        let document = try fixture()
        try ProceduralSinger.validate(document)
        let signal = try ProceduralSinger.render(document)
        let silent = try ProceduralSinger.render(document, muteNotes: true)
        XCTAssertEqual(signal.samples.count, 75120)
        XCTAssertGreaterThan(signal.rms, 0.01)
        XCTAssertLessThanOrEqual(signal.peak, 0.60)
        XCTAssertEqual(silent.rms, 0)
        XCTAssertTrue(signal.samples.allSatisfy(\.isFinite))
        XCTAssertEqual(signal.samples, try ProceduralSinger.render(document).samples)
    }

    func testRealtimeFricativeTransitionKeepsOneVoiceAndNoBufferTimingDependency() throws {
        let doc = try fixture()
        let prep = try prepared(doc)
        let a = RealtimeSinger(prepared: prep).renderOffline(blockFrames: 64)
        let b = RealtimeSinger(prepared: prep).renderOffline(blockFrames: 723)
        XCTAssertEqual(a.samples, b.samples)
        XCTAssertGreaterThan(a.rms, 0.0002)
        XCTAssertLessThan(a.peak, 1)
        XCTAssertTrue(a.samples.allSatisfy(\.isFinite))
    }

    func testSpectralNoiseDiffersFromNucleusAtSameAuthoredPitch() throws {
        let audio = RealtimeSinger(prepared: try prepared(fixture())).renderOffline()
        // First syllable starts with /s/; the later /ɑ/ carries harmonics at same MIDI note.
        func variation(_ slice: ArraySlice<Float>) -> Double {
            let a = Array(slice)
            let rms = sqrt(a.reduce(0.0) { $0 + pow(Double($1), 2) } / Double(a.count))
            let derivative = sqrt(zip(a.dropFirst(),a).reduce(0.0) {
                $0 + pow(Double($1.0 - $1.1), 2)
            } / Double(a.count-1))
            return derivative / max(rms, 1e-8)
        }
        let onset = variation(audio.samples[960..<2400])
        let vowel = variation(audio.samples[7200..<8640])
        XCTAssertGreaterThan(onset, vowel * 1.10)
    }

    func testUnknownConsonantsStillFailClosed() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("examples/air-syllables.json"),
                                encoding: .utf8)
        let unsupported = source.replacingOccurrences(of: "\"symbol\" : \"s\"",
                                                       with: "\"symbol\" : \"ʃ\"")
        // JSON formatting may differ; replace the exact known field value, not all phonemes.
        let modified = unsupported == source ?
            source.replacingOccurrences(of: "\"symbol\": \"s\"", with: "\"symbol\": \"ʃ\"") :
            unsupported
        let doc = try JSONDecoder().decode(PhraseDocument.self, from: Data(modified.utf8))
        XCTAssertThrowsError(try ProceduralSinger.validate(doc))
    }
}
