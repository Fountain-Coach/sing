import Foundation

/// Bounded controls for a synthetic source-filter tract, not a measurement of physiology.
/// This is the source-owned acoustic model for Teatro Ear, separate from a MIDI message.
public struct SingTractControls: Equatable {
    public let airflow: Double
    public let constriction: Double
    public let voicing: Double
    public let pitchHz: Double
    public let openness: Double
    public let frontness: Double
    public let level: Double

    public init(airflow: Double, constriction: Double, voicing: Double,
                pitchHz: Double = 180, openness: Double = 0.6,
                frontness: Double = 0.5, level: Double = 0.5) throws {
        let unit = [airflow, constriction, voicing, openness, frontness, level]
        guard unit.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              pitchHz.isFinite, (50...1500).contains(pitchHz) else {
            throw SingError.invalid("Tract controls must be finite and within declared ranges")
        }
        self.airflow = airflow
        self.constriction = constriction
        self.voicing = voicing
        self.pitchHz = pitchHz
        self.openness = openness
        self.frontness = frontness
        self.level = level
    }

    /// These are experimental source-filter conditions, not recorded human breath.
    public static func openBreath() -> SingTractControls {
        // All fixed presets have been validated by their literal bounds.
        try! SingTractControls(airflow: 0.78, constriction: 0.06, voicing: 0,
                               openness: 0.74, frontness: 0.45)
    }
    public static func narrowBreath() -> SingTractControls {
        try! SingTractControls(airflow: 0.78, constriction: 0.92, voicing: 0,
                               openness: 0.46, frontness: 0.70)
    }
    public static func phonation() -> SingTractControls {
        try! SingTractControls(airflow: 0.78, constriction: 0.18, voicing: 0.92,
                               pitchHz: 196, openness: 0.65, frontness: 0.5)
    }
    public static func silence() -> SingTractControls {
        try! SingTractControls(airflow: 0, constriction: 0, voicing: 0, level: 0)
    }
}

/// Original, parameter-variable resonator. Update coefficients only at control rate;
/// process individual audio frames without allocating or reconstructing filter state.
private struct MovingFormant {
    private var b0 = 0.0
    private var b2 = 0.0
    private var a1 = 0.0
    private var a2 = 0.0
    private var z1 = 0.0
    private var z2 = 0.0

    mutating func tune(center: Double, width: Double, rate: Double) {
        let fc = min(max(75, center), rate * 0.42)
        let omega = 2 * Double.pi * fc / rate
        let alpha = sin(omega) * min(max(width, 70), rate * 0.30) / (2 * fc)
        let inverse = 1 / (1 + alpha)
        b0 = alpha * inverse
        b2 = -alpha * inverse
        a1 = -2 * cos(omega) * inverse
        a2 = (1 - alpha) * inverse
    }

    @inline(__always) mutating func sample(_ input: Double) -> Double {
        let output = b0 * input + z1
        z1 = -a1 * output + z2
        z2 = b2 * input - a2 * output
        return output
    }

    mutating func reset() { z1 = 0; z2 = 0 }
}

/// A continuous, original breath-to-phonation acoustic instrument.
/// - One owner/audio thread calls render(into:) and setControls(_:) sequentially.
/// - No MIDI decoding, OS audio, memory allocation, logging, locks or file I/O in render.
/// - Noise is seed-controlled aperiodic excitation; *only* voiced excitation is periodic.
/// - Vocal tract parameters describe a source/filter approximation, not an anatomical CFD model.
public final class SingVocalTract {
    public let sampleRate: Int
    public let seed: UInt32

    private var requested: SingTractControls
    private var airflow = 0.0
    private var constriction = 0.0
    private var voicing = 0.0
    private var openness = 0.6
    private var frontness = 0.5
    private var level = 0.0
    private var pitchHz = 180.0

    private var noise: UInt32
    private var lowNoise = 0.0
    private var phase = 0.0
    private var first = MovingFormant()
    private var second = MovingFormant()
    private var third = MovingFormant()
    private let smooth: Double
    private var sampleIndex = 0

    public private(set) var framesRendered = 0

    public init(sampleRate: Int = 48_000, seed: UInt32 = 0x4B6D_1C27,
                initial: SingTractControls = .silence()) throws {
        guard (16_000...192_000).contains(sampleRate), seed != 0 else {
            throw SingError.invalid("Unsupported tract sample rate or zero noise seed")
        }
        self.sampleRate = sampleRate
        self.seed = seed
        self.noise = seed
        self.requested = initial
        self.smooth = 1 - exp(-1 / (0.018 * Double(sampleRate)))
        self.openness = initial.openness
        self.frontness = initial.frontness
        self.pitchHz = initial.pitchHz
        tuneFormants()
    }

    public func setControls(_ controls: SingTractControls) {
        // Command-thread values have been validated by the value object's initializer.
        requested = controls
    }

    public func reset(to controls: SingTractControls = .silence()) {
        requested = controls
        airflow = 0
        // Match the constructor's neutral, silent starting tract exactly.
        // Reset changes the target but preserves the same smooth onset path.
        constriction = 0
        voicing = 0
        openness = 0.6
        frontness = 0.5
        level = 0
        pitchHz = 180
        noise = seed
        lowNoise = 0
        phase = 0
        first.reset(); second.reset(); third.reset()
        sampleIndex = 0
        framesRendered = 0
        tuneFormants()
    }

    private func tuneFormants() {
        // Physically motivated formant direction: opening raises F1; fronting raises F2.
        // Calibration values remain *provisional* until measured vocal-tract samples exist.
        let rate = Double(sampleRate)
        first.tune(center: 260 + 620 * openness, width: 115 + 90 * openness, rate: rate)
        second.tune(center: 800 + 1650 * frontness - 160 * openness, width: 170, rate: rate)
        third.tune(center: 2350 + 600 * frontness, width: 330, rate: rate)
    }

    @inline(__always) private func oneSample() -> Float {
        airflow += (requested.airflow - airflow) * smooth
        constriction += (requested.constriction - constriction) * smooth
        voicing += (requested.voicing - voicing) * smooth
        openness += (requested.openness - openness) * smooth
        frontness += (requested.frontness - frontness) * smooth
        level += (requested.level - level) * smooth
        pitchHz += (requested.pitchHz - pitchHz) * smooth
        // Stable control-rate coefficient update; never periodic gain/volume modulation.
        if sampleIndex & 63 == 0 { tuneFormants() }
        sampleIndex &+= 1
        framesRendered &+= 1

        // Independent aperiodic turbulence generated from a source-owned fixed seed.
        noise ^= noise << 13
        noise ^= noise >> 17
        noise ^= noise << 5
        let white = Double(noise) / Double(UInt32.max) * 2 - 1
        lowNoise += (white - lowNoise) * 0.07
        let broadband = 0.8 * lowNoise + 0.2 * white
        let highFrequency = white - lowNoise
        let aspiration = broadband * (1 - constriction) + highFrequency * constriction

        // The vocal folds enter *without* advancing the resonance clock or noise seed.
        // Use the existing anti-aliased glottal source geometry from SingVoice.
        let rate = Double(sampleRate)
        let increment = min(0.45, pitchHz / rate)
        let t = phase
        var saw = 2 * t - 1
        if t < increment {
            let x = t / increment
            saw -= 2 * x - x * x - 1
        } else if t > 1 - increment {
            let x = (t - 1) / increment
            saw -= x * x + 2 * x + 1
        }
        phase += increment
        if phase >= 1 { phase -= 1 }

        let excitation = aspiration * (1 - 0.83 * voicing) + saw * voicing * 0.45
        let resonant = first.sample(excitation) * 0.85
            + second.sample(excitation) * 0.83
            + third.sample(excitation) * 0.40
        // Constricted breath retains a direct aspiration path, as observed in
        // turbulent consonants; no arbitrary recurring swell or pulse generator.
        let directAir = aspiration * (1 - voicing) * (0.06 + 0.18 * constriction)
        let signal = (resonant + directAir) * airflow * level * 0.78
        return Float(max(-1, min(1, signal)))
    }

    public func render(into output: UnsafeMutableBufferPointer<Float>) {
        for index in output.indices { output[index] = oneSample() }
    }

    /// A finite *evidence capture* of a potentially indefinite patch.
    public func capture(frames: Int, blockFrames: Int = 256) throws -> RenderedSound {
        guard frames > 0, frames <= sampleRate * 60,
              (1...8192).contains(blockFrames) else {
            throw SingError.invalid("Tract capture must be bounded to 60 seconds")
        }
        var samples = [Float](repeating: 0, count: frames)
        var scratch = [Float](repeating: 0, count: blockFrames)
        var offset = 0
        while offset < frames {
            let n = min(blockFrames, frames - offset)
            scratch.withUnsafeMutableBufferPointer {
                render(into: UnsafeMutableBufferPointer(start: $0.baseAddress, count: n))
            }
            for i in 0..<n { samples[offset+i] = scratch[i] }
            offset += n
        }
        return RenderedSound(sampleRate: sampleRate, samples: samples)
    }
}
