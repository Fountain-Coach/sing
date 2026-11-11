import Foundation
import XCTest
@testable import SingVoice

final class SingVocalTractTests: XCTestCase {
    private func make(_ initial: SingTractControls, seed: UInt32 = 0x4B6D_1C27) throws -> SingVocalTract {
        let synth = try SingVocalTract(sampleRate: 48_000, seed: seed)
        synth.setControls(initial)
        return synth
    }

    private func data(_ state: SingTractControls, frames: Int = 96_000) throws -> RenderedSound {
        try make(state).capture(frames: frames)
    }

    private func difference(_ a: [Float]) -> Double {
        var sum = 0.0
        for i in 1..<a.count { sum += pow(Double(a[i] - a[i-1]), 2) }
        return sqrt(sum / Double(a.count-1))
    }

    func testSilenceIsTrueDigitalSilenceEvenWithActiveClock() throws {
        let sound = try data(.silence())
        XCTAssertEqual(sound.rms, 0)
        XCTAssertEqual(sound.peak, 0)
        XCTAssertEqual(sound.samples.count, 96_000)
    }

    func testUnvoicedBreathAndConstrictionDifferSpectrally() throws {
        let open = try data(.openBreath())
        let narrow = try data(.narrowBreath())
        XCTAssertGreaterThan(open.rms, 0.001)
        XCTAssertGreaterThan(narrow.rms, 0.001)
        XCTAssertNotEqual(open.samples, narrow.samples)
        XCTAssertGreaterThan(difference(narrow.samples) / narrow.rms,
                             difference(open.samples) / open.rms * 1.10,
                             "A constriction should yield more high-frequency variation than open breath")
        XCTAssertLessThan(open.peak, 1)
        XCTAssertLessThan(narrow.peak, 1)
    }

    func testPhonationAddsPeriodicExcitationWithoutRewritingBreath() throws {
        let open = try data(.openBreath())
        let voiced = try data(.phonation())
        XCTAssertNotEqual(voiced.samples, open.samples)
        XCTAssertGreaterThan(voiced.rms, 0.005)
        XCTAssertGreaterThan(voiced.peak, 0.01)
        XCTAssertLessThan(voiced.peak, 1)
    }

    func testBitIdenticalSeedAndExactBlockFrameParity() throws {
        let a = try make(.narrowBreath())
        let b = try make(.narrowBreath())
        let first = try a.capture(frames: 48_000, blockFrames: 64)
        let second = try b.capture(frames: 48_000, blockFrames: 1023)
        XCTAssertEqual(first.samples, second.samples)
        let third = try make(.narrowBreath(), seed: 0x12345678)
            .capture(frames: 48_000)
        XCTAssertNotEqual(first.samples, third.samples)
    }

    func testContinuousPastNineSecondsAndLiveArticulationChange() throws {
        let a = try make(.openBreath())
        let first = try a.capture(frames: 48_000 * 10)
        XCTAssertGreaterThan(first.samples.suffix(4_800)
            .reduce(0.0) { $0 + abs(Double($1)) }, 0.1)
        a.setControls(.narrowBreath())
        let changed = try a.capture(frames: 48_000)
        XCTAssertGreaterThan(changed.rms, 0.001)
        XCTAssertEqual(a.framesRendered, 48_000 * 11)
        a.setControls(.silence())
        let stop = try a.capture(frames: 48_000 / 2)
        let latePeak = stop.samples.suffix(4_800)
            .reduce(0.0) { max($0, abs(Double($1))) }
        XCTAssertLessThan(latePeak, 0.0005)
    }

    func testInputSafetyAndFiniteAudio() throws {
        XCTAssertThrowsError(try SingTractControls(
            airflow: .nan, constriction: 0, voicing: 0))
        XCTAssertThrowsError(try SingTractControls(
            airflow: 1, constriction: 1.1, voicing: 0))
        XCTAssertThrowsError(try SingTractControls(
            airflow: 1, constriction: 0, voicing: 1, pitchHz: 0))
        XCTAssertThrowsError(try SingVocalTract(sampleRate: 7_000))
        XCTAssertThrowsError(try SingVocalTract(seed: 0))
        let synth = try make(.phonation())
        XCTAssertThrowsError(try synth.capture(frames: 0))
        XCTAssertThrowsError(try synth.capture(frames: 3_000_000))
        let pcm = try synth.capture(frames: 24_000)
        XCTAssertTrue(pcm.samples.allSatisfy(\.isFinite))
    }

    func testResetRestoresSameAudibleSampleSequence() throws {
        let synth = try make(.phonation())
        let a = try synth.capture(frames: 24_000)
        synth.reset(to: .phonation())
        let b = try synth.capture(frames: 24_000)
        XCTAssertEqual(a.samples, b.samples)
    }
}
