import Foundation

// A native, original procedural voice. No sampled human voice or vendor plug-in.
// Offline score rendering only: transport and live MIDI 2.0 event dispatch are future integration work.
public enum SingError: Error, CustomStringConvertible {
    case invalid(String)
    public var description: String {
        switch self { case .invalid(let reason): return reason }
    }
}

public struct PhraseDocument: Decodable {
    public struct Source: Decodable { public let kind: String; public let text: String; public let rights: String }
    public struct Phoneme: Decodable { public let symbol: String; public let role: String }
    public struct Syllable: Decodable {
        public let id: String
        public let text: String
        public let phonemes: [Phoneme]
    }
    public struct Phrase: Decodable { public let syllables: [Syllable] }
    public struct Note: Decodable {
        public let id: String
        public let syllableId: String
        public let pitch: Int
        public let onMs: Int
        public let offMs: Int
        public let velocity16: Int
        public let advanceSyllable: Bool
    }
    public struct Performance: Decodable { public let timebase: String; public let notes: [Note] }
    public struct RenderIntent: Decodable { public let state: String; public let release: String }
    public let schema: String
    public let source: Source
    public let phrase: Phrase
    public let performance: Performance
    public let renderIntent: RenderIntent
}

public struct RenderedSound {
    public let sampleRate: Int
    public let samples: [Float]
    /// Renderer-neutral PCM container, usable by separately authorized vocal engines.
    public init(sampleRate: Int, samples: [Float]) {
        self.sampleRate = sampleRate
        self.samples = samples
    }
    public var peak: Double { samples.reduce(0) { max($0, abs(Double($1))) } }
    public var rms: Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
    }
}

/// Transient performance data derived from typed MIDI 2.0 packets.
/// Authored syllable identity stays outside Universal MIDI Packets.
public struct SingPerformanceNote {
    public struct PressurePoint {
        public let timeMs: Int
        public let normalized: Double
        public init(timeMs: Int, normalized: Double) {
            self.timeMs = timeMs
            self.normalized = normalized
        }
    }
    public struct PitchPoint {
        public let timeMs: Int
        /// Channel pitch bend, instrument-configured to +/- two semitones.
        public let semitones: Double
        public init(timeMs: Int, semitones: Double) {
            self.timeMs = timeMs
            self.semitones = semitones
        }
    }
    public struct BreathPoint {
        public let timeMs: Int
        /// MIDI 2.0 Control Change 2 (breath controller), normalized 0...1.
        public let normalized: Double
        public init(timeMs: Int, normalized: Double) {
            self.timeMs = timeMs
            self.normalized = normalized
        }
    }
    public let id: String
    public let syllableId: String
    public let pitch: Int
    public let onMs: Int
    public let offMs: Int
    public let velocity16: Int
    public let pressurePoints: [PressurePoint]
    public let pitchPoints: [PitchPoint]
    public let breathPoints: [BreathPoint]

    public init(id: String, syllableId: String, pitch: Int, onMs: Int,
                offMs: Int, velocity16: Int, pressurePoints: [PressurePoint] = [],
                pitchPoints: [PitchPoint] = [], breathPoints: [BreathPoint] = []) {
        self.id = id
        self.syllableId = syllableId
        self.pitch = pitch
        self.onMs = onMs
        self.offMs = offMs
        self.velocity16 = velocity16
        self.pressurePoints = pressurePoints
        self.pitchPoints = pitchPoints
        self.breathPoints = breathPoints
    }
}

struct Formant {
    let frequency: Double
    let width: Double
    let gain: Double
}

// A real, stateful resonator (RBJ constant-skirt-gain bandpass), not a pre-recorded vowel.
struct Resonator {
    let b0: Double
    let b2: Double
    let a1: Double
    let a2: Double
    var z1 = 0.0
    var z2 = 0.0

    init(center: Double, bandwidth: Double, sampleRate: Double) {
        let omega = 2 * Double.pi * center / sampleRate
        let alpha = sin(omega) * bandwidth / (2 * center)
        let norm = 1 / (1 + alpha)
        b0 = alpha * norm
        b2 = -alpha * norm
        a1 = -2 * cos(omega) * norm
        a2 = (1 - alpha) * norm
    }

    mutating func process(_ sample: Double) -> Double {
        let output = b0 * sample + z1
        z1 = -a1 * output + z2
        z2 = b2 * sample - a2 * output
        return output
    }
}

struct VoiceBank {
    var bands: [Resonator]
    let gains: [Double]
    init(_ formants: [Formant], sampleRate: Double) {
        bands = formants.map { Resonator(center: $0.frequency, bandwidth: $0.width, sampleRate: sampleRate) }
        gains = formants.map(\.gain)
    }
    mutating func sample(_ excitation: Double) -> Double {
        var output = 0.0
        for i in bands.indices { output += gains[i] * bands[i].process(excitation) }
        return output
    }
}

struct Glottis {
    var increment: Double
    var phase = 0.0
    init(midiPitch: Int, sampleRate: Double) {
        let frequency = 440 * pow(2, Double(midiPitch - 69) / 12)
        increment = frequency / sampleRate
    }
    // PolyBLEP softens the sawtooth discontinuity, reducing aliasing.
    mutating func sample() -> Double {
        let t = phase
        var saw = 2 * t - 1
        if t < increment {
            let x = t / increment
            saw -= x + x - x * x - 1
        } else if t > 1 - increment {
            let x = (t - 1) / increment
            saw -= x * x + x + x + 1
        }
        phase += increment
        if phase >= 1 { phase -= 1 }
        return saw
    }
}

public enum ProceduralSinger {
    public static func validate(_ document: PhraseDocument) throws {
        guard document.schema == "sing.phrase.v1", document.performance.timebase == "milliseconds" else {
            throw SingError.invalid("Unsupported authored phrase/timebase")
        }
        guard document.source.kind == "synthetic", !document.source.rights.isEmpty else {
            throw SingError.invalid("This demo only admits original synthetic phrases")
        }
        guard document.renderIntent.state == "not-rendered", document.renderIntent.release == "not-admitted" else {
            throw SingError.invalid("Authored input cannot claim rendered or published status")
        }
        let syllables = document.phrase.syllables
        guard !syllables.isEmpty, Set(syllables.map(\.id)).count == syllables.count else {
            throw SingError.invalid("Missing or repeated syllable identity")
        }
        for s in syllables {
            guard s.phonemes.count == 2, s.phonemes[0].role == "onset", s.phonemes[1].role == "nucleus",
                  ["l", "m", "n"].contains(s.phonemes[0].symbol),
                  ["ɑ", "i"].contains(s.phonemes[1].symbol) else {
                throw SingError.invalid("Unsupported phonetic state in \(s.id); only l/m/n + ɑ/i is implemented")
            }
        }
        guard !document.performance.notes.isEmpty else { throw SingError.invalid("No performance notes") }
        var previousOff = -1
        var seenSyllables = Set<String>()
        var seenNotes = Set<String>()
        var previousSyllable: String?
        for n in document.performance.notes {
            guard !n.id.isEmpty, seenNotes.insert(n.id).inserted,
                  n.onMs >= 0, n.offMs > n.onMs, n.onMs >= previousOff,
                  (0...127).contains(n.pitch), (1...65535).contains(n.velocity16) else {
                throw SingError.invalid("Invalid, overlapping, or duplicate note \(n.id)")
            }
            let sid = n.syllableId
            guard syllables.contains(where: { $0.id == sid }) else {
                throw SingError.invalid("Note references unknown syllable")
            }
            if sid == previousSyllable {
                guard !n.advanceSyllable else {
                    throw SingError.invalid("Melisma must sustain the same syllable without retriggering")
                }
            } else {
                guard n.advanceSyllable, seenSyllables.insert(sid).inserted else {
                    throw SingError.invalid("New syllable requires one explicit advance; no backward cursor")
                }
            }
            previousSyllable = sid
            previousOff = n.offMs
        }
    }

    private static func shape(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    static func formants(for phoneme: String) -> [Formant] {
        switch phoneme {
        case "l": return [Formant(frequency: 440, width: 180, gain: 0.7), Formant(frequency: 1200, width: 260, gain: 0.8), Formant(frequency: 2550, width: 350, gain: 0.5)]
        case "m": return [Formant(frequency: 280, width: 120, gain: 0.9), Formant(frequency: 1050, width: 220, gain: 0.22), Formant(frequency: 2300, width: 320, gain: 0.08)]
        case "n": return [Formant(frequency: 315, width: 130, gain: 0.9), Formant(frequency: 1480, width: 260, gain: 0.24), Formant(frequency: 2500, width: 300, gain: 0.08)]
        case "i": return [Formant(frequency: 290, width: 100, gain: 1), Formant(frequency: 2300, width: 260, gain: 1.2), Formant(frequency: 3150, width: 320, gain: 0.55)]
        default: return [Formant(frequency: 780, width: 185, gain: 1), Formant(frequency: 1200, width: 250, gain: 0.85), Formant(frequency: 2850, width: 380, gain: 0.5)] // ɑ
        }
    }

    public static func render(_ document: PhraseDocument, sampleRate: Int = 48000,
                              muteNotes: Bool = false,
                              performanceNotes: [SingPerformanceNote]? = nil) throws -> RenderedSound {
        try validate(document)
        guard (16000...192000).contains(sampleRate) else {
            throw SingError.invalid("Unsupported sample rate")
        }
        let notes = performanceNotes ?? document.performance.notes.map {
            SingPerformanceNote(id: $0.id, syllableId: $0.syllableId,
                                pitch: $0.pitch, onMs: $0.onMs, offMs: $0.offMs,
                                velocity16: $0.velocity16)
        }
        let authored = document.performance.notes
        guard notes.count == authored.count else {
            throw SingError.invalid("Performed note count does not match authored phrase")
        }
        var previousOff = -1
        for (index, note) in notes.enumerated() {
            guard note.id == authored[index].id,
                  note.syllableId == authored[index].syllableId,
                  (0...127).contains(note.pitch), (1...65535).contains(note.velocity16),
                  note.onMs >= previousOff, note.offMs > note.onMs else {
                throw SingError.invalid("Performed note timing or identity invalid")
            }
            var previousPressure = -1
            for point in note.pressurePoints {
                guard point.timeMs >= note.onMs, point.timeMs <= note.offMs,
                      point.timeMs >= previousPressure, point.normalized.isFinite,
                      (0.0...1.0).contains(point.normalized) else {
                    throw SingError.invalid("Invalid per-note pressure timeline")
                }
                previousPressure = point.timeMs
            }
            previousOff = note.offMs
        }
        let tailMs = 85
        let lastOff = notes.last!.offMs
        let frameCount = Int(ceil(Double(lastOff + tailMs) * Double(sampleRate) / 1000))
        var output = [Float](repeating: 0, count: frameCount)
        guard !muteNotes else { return RenderedSound(sampleRate: sampleRate, samples: output) }
        let syllablesByID = Dictionary(uniqueKeysWithValues: document.phrase.syllables.map { ($0.id, $0) })
        let rate = Double(sampleRate)

        for note in notes {
            let syllable = syllablesByID[note.syllableId]!
            var onset = VoiceBank(formants(for: syllable.phonemes[0].symbol), sampleRate: rate)
            var nucleus = VoiceBank(formants(for: syllable.phonemes[1].symbol), sampleRate: rate)
            var glottis = Glottis(midiPitch: note.pitch, sampleRate: rate)
            let onFrame = Int(round(Double(note.onMs) * rate / 1000))
            let offFrame = Int(round(Double(note.offMs) * rate / 1000))
            let endFrame = min(output.count, offFrame + Int(round(0.075 * rate)))
            let duration = Double(note.offMs - note.onMs) / 1000
            let velocity = Double(note.velocity16) / 65535
            var pressureIndex = 0
            var targetGain = 1.0
            var smoothedGain = 1.0
            let pressureSmoothing = 1 - exp(-1 / (0.012 * rate))
            for frame in onFrame..<endFrame {
                let absoluteMs = Double(frame) * 1000 / rate
                while pressureIndex < note.pressurePoints.count &&
                      Double(note.pressurePoints[pressureIndex].timeMs) <= absoluteMs {
                    targetGain = 0.35 + 1.30 * note.pressurePoints[pressureIndex].normalized
                    pressureIndex += 1
                }
                smoothedGain += (targetGain - smoothedGain) * pressureSmoothing
                let t = Double(frame - onFrame) / rate
                let attack = shape(t / 0.012)
                let release = t <= duration ? 1 : 1 - shape((t - duration) / 0.070)
                let onsetMix = 1 - shape((t - 0.025) / 0.095)
                let source = glottis.sample()
                let a = onset.sample(source)
                let b = nucleus.sample(source)
                let gain = attack * release * (0.7 + 0.3 * velocity) * smoothedGain
                let sample = gain * (a * onsetMix * 0.65 + b * (1 - onsetMix))
                output[frame] += Float(sample)
            }
        }
        let peak = output.reduce(0.0) { max($0, abs(Double($1))) }
        guard peak.isFinite, peak > 0.000001 else { throw SingError.invalid("Native renderer produced silence") }
        // Normalize a private audition file, not a loudness-mastered publication.
        let level = 0.58 / peak
        for index in output.indices { output[index] = Float(Double(output[index]) * level) }
        return RenderedSound(sampleRate: sampleRate, samples: output)
    }
}

public enum WaveWriter {
    public static func write(_ sound: RenderedSound, to url: URL) throws {
        guard sound.samples.count < Int(UInt32.max / 2) else { throw SingError.invalid("WAV exceeds RIFF length") }
        let count = sound.samples.count
        let bytes = UInt32(count * 2)
        var data = Data(capacity: 44 + Int(bytes))
        func ascii(_ string: String) { data.append(contentsOf: string.utf8) }
        func littleEndian<T: FixedWidthInteger>(_ value: T) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        ascii("RIFF"); littleEndian(UInt32(36) + bytes)
        ascii("WAVEfmt "); littleEndian(UInt32(16)); littleEndian(UInt16(1))
        littleEndian(UInt16(1)); littleEndian(UInt32(sound.sampleRate))
        littleEndian(UInt32(sound.sampleRate * 2)); littleEndian(UInt16(2)); littleEndian(UInt16(16))
        ascii("data"); littleEndian(bytes)
        for sample in sound.samples {
            guard sample.isFinite else { throw SingError.invalid("Non-finite PCM frame") }
            let clipped = min(1, max(-1, Double(sample)))
            let pcm = Int16((clipped * 32767).rounded())
            littleEndian(UInt16(bitPattern: pcm))
        }
        try data.write(to: url, options: .atomic)
    }
}
