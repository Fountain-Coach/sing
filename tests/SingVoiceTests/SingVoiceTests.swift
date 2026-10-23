import Foundation
import XCTest
@testable import SingVoice

final class SingVoiceTests: XCTestCase {
    private func fixture() throws -> PhraseDocument {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("examples/three-syllables.json"))
        return try JSONDecoder().decode(PhraseDocument.self, from: data)
    }

    func testNativeSyllablesMakeMeasuredPCM() throws {
        let rendered = try ProceduralSinger.render(fixture())
        XCTAssertEqual(rendered.sampleRate, 48000)
        XCTAssertEqual(rendered.samples.count, 75120)
        XCTAssertGreaterThan(rendered.rms, 0.01)
        XCTAssertGreaterThan(rendered.peak, 0.5)
        XCTAssertLessThan(rendered.peak, 0.95)
        XCTAssertTrue(rendered.samples.allSatisfy(\.isFinite))
    }

    func testNoNotesNegativeControlIsSilent() throws {
        let rendered = try ProceduralSinger.render(fixture(), muteNotes: true)
        XCTAssertEqual(rendered.rms, 0)
        XCTAssertEqual(rendered.peak, 0)
    }

    func testRepeatRenderIsDeterministic() throws {
        let doc = try fixture()
        let first = try ProceduralSinger.render(doc)
        let second = try ProceduralSinger.render(doc)
        XCTAssertEqual(first.samples, second.samples)
    }

    func testWavIsPCM() throws {
        let rendered = try ProceduralSinger.render(fixture())
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: dest) }
        try WaveWriter.write(rendered, to: dest)
        let data = try Data(contentsOf: dest)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data.subdata(in: 8..<12), as: UTF8.self), "WAVE")
        XCTAssertEqual(data.count, 44 + rendered.samples.count * 2)
    }

    func testRejectUnsupportedPhoneme() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let json = try String(contentsOf: root.appendingPathComponent("examples/three-syllables.json"), encoding: .utf8)
        let modified = json.replacingOccurrences(of: "\"symbol\": \"l\"", with: "\"symbol\": \"ʃ\"")
        let doc = try JSONDecoder().decode(PhraseDocument.self, from: Data(modified.utf8))
        XCTAssertThrowsError(try ProceduralSinger.render(doc))
    }
}
