import Foundation

// Sample-accurate, preflighted event schedule. No new MIDI representation is invented:
// SingMIDI2 decodes the existing typed UMP messages BEFORE the audio callback.
private struct ThreeFormants {
    var first: Resonator
    var second: Resonator
    var third: Resonator
    let firstGain: Double
    let secondGain: Double
    let thirdGain: Double

    init(_ description: [Formant], sampleRate: Double) {
        precondition(description.count == 3)
        first = Resonator(center: description[0].frequency, bandwidth: description[0].width, sampleRate: sampleRate)
        second = Resonator(center: description[1].frequency, bandwidth: description[1].width, sampleRate: sampleRate)
        third = Resonator(center: description[2].frequency, bandwidth: description[2].width, sampleRate: sampleRate)
        firstGain = description[0].gain
        secondGain = description[1].gain
        thirdGain = description[2].gain
    }

    @inline(__always) mutating func filter(_ sample: Double) -> Double {
        firstGain * first.process(sample) +
        secondGain * second.process(sample) +
        thirdGain * third.process(sample)
    }
}

public enum SingArticulation: String, CaseIterable {
    case plain
    case articulated
}

private struct PhoneticColor {
    let consonant: ThreeFormants
    let vowel: ThreeFormants
    let onset: UInt8 // l, m, n: local phoneme identity, not a MIDI message
}

private enum VoiceAction {
    case noteOn(syllableIndex: Int, pitch: Int, phaseIncrement: Double, velocity: Double, advance: Bool)
    case noteOff(pitch: Int)
    case pressure(pitch: Int, normalized: Double)
    case pitchBend(pitch: Int, multiplier: Double)
    case breath(pitch: Int, normalized: Double)
}

private struct VoiceEvent {
    let frame: Int
    let priority: Int
    let action: VoiceAction
}

public struct RealtimePreparedPhrase {
    public let sampleRate: Int
    public let frameCount: Int
    public let noteCount: Int
    public let eventCount: Int
    public let vibratoCents: Double
    public let articulation: SingArticulation
    fileprivate let voices: [PhoneticColor]
    fileprivate let events: [VoiceEvent]

    public init(document: PhraseDocument, notes: [SingPerformanceNote],
                sampleRate: Int = 48_000, vibratoCents: Double = 0,
                articulation: SingArticulation = .plain) throws {
        try ProceduralSinger.validate(document)
        guard vibratoCents.isFinite, (0.0...50.0).contains(vibratoCents) else {
            throw SingError.invalid("Vibrato depth must be 0...50 cents")
        }
        guard (16_000...192_000).contains(sampleRate) else {
            throw SingError.invalid("Unsupported real-time sample rate")
        }
        let authored = document.performance.notes
        guard notes.count == authored.count, !notes.isEmpty else {
            throw SingError.invalid("Performed note count differs from authored phrase")
        }
        let rate = Double(sampleRate)
        let voiceColors = document.phrase.syllables.map { syllable in
            PhoneticColor(
                consonant: ThreeFormants(ProceduralSinger.formants(for: syllable.phonemes[0].symbol), sampleRate: rate),
                vowel: ThreeFormants(ProceduralSinger.formants(for: syllable.phonemes[1].symbol), sampleRate: rate),
                onset: syllable.phonemes[0].symbol == "m" ? 1 : (syllable.phonemes[0].symbol == "n" ? 2 : 0))
        }
        var timeline: [VoiceEvent] = []
        timeline.reserveCapacity(notes.count * 3 + 16)
        var previousOff = -1
        for (index, note) in notes.enumerated() {
            let score = authored[index]
            guard note.id == score.id, note.syllableId == score.syllableId,
                  (0...127).contains(note.pitch), (1...65_535).contains(note.velocity16),
                  note.onMs >= previousOff, note.offMs > note.onMs,
                  note.offMs <= 60_000 else {
                throw SingError.invalid("Invalid bounded performance or original note identity")
            }
            guard let syllableIndex = document.phrase.syllables.firstIndex(where: { $0.id == note.syllableId }) else {
                throw SingError.invalid("Unknown syllable identity")
            }
            let fundamental = 440 * pow(2, Double(note.pitch - 69) / 12)
            let start = Int((Double(note.onMs) * rate / 1000).rounded())
            let end = Int((Double(note.offMs) * rate / 1000).rounded())
            guard end > start else { throw SingError.invalid("Note shorter than one audio frame") }
            timeline.append(VoiceEvent(frame: start, priority: 1,
                action: .noteOn(syllableIndex: syllableIndex, pitch: note.pitch,
                                phaseIncrement: fundamental / rate,
                                velocity: Double(note.velocity16) / 65_535,
                                advance: score.advanceSyllable)))
            timeline.append(VoiceEvent(frame: end, priority: 0, action: .noteOff(pitch: note.pitch)))
            var previousPressure = -1
            for point in note.pressurePoints {
                guard point.timeMs >= note.onMs, point.timeMs < note.offMs,
                      point.timeMs > previousPressure,
                      point.normalized.isFinite, (0...1).contains(point.normalized) else {
                    throw SingError.invalid("Invalid timed polyphonic pressure")
                }
                timeline.append(VoiceEvent(frame: Int((Double(point.timeMs) * rate / 1000).rounded()),
                                           priority: 2,
                                           action: .pressure(pitch: note.pitch, normalized: point.normalized)))
                previousPressure = point.timeMs
            }
            var lastPitchPoint = -1
            for point in note.pitchPoints {
                guard point.timeMs >= note.onMs, point.timeMs < note.offMs,
                      point.timeMs > lastPitchPoint, point.semitones.isFinite,
                      (-2.0...2.0).contains(point.semitones) else {
                    throw SingError.invalid("Invalid per-note pitch bend timeline")
                }
                timeline.append(VoiceEvent(frame: Int((Double(point.timeMs) * rate / 1000).rounded()),
                                           priority: 2, action: .pitchBend(
                                            pitch: note.pitch,
                                            multiplier: pow(2.0, point.semitones / 12.0))))
                lastPitchPoint = point.timeMs
            }
            var lastBreathPoint = -1
            for point in note.breathPoints {
                guard point.timeMs >= note.onMs, point.timeMs < note.offMs,
                      point.timeMs > lastBreathPoint, point.normalized.isFinite,
                      (0.0...1.0).contains(point.normalized) else {
                    throw SingError.invalid("Invalid per-note breath timeline")
                }
                timeline.append(VoiceEvent(frame: Int((Double(point.timeMs) * rate / 1000).rounded()),
                                           priority: 2,
                                           action: .breath(pitch: note.pitch, normalized: point.normalized)))
                lastBreathPoint = point.timeMs
            }
            previousOff = note.offMs
        }
        timeline.sort {
            $0.frame == $1.frame ? $0.priority < $1.priority : $0.frame < $1.frame
        }
        self.sampleRate = sampleRate
        self.vibratoCents = vibratoCents
        self.articulation = articulation
        self.frameCount = Int((Double(notes.last!.offMs + 400) * rate / 1000).rounded())
        self.noteCount = notes.count
        self.eventCount = timeline.count
        self.events = timeline
        self.voices = voiceColors
    }
}

/// The only mutable render-time state; one caller/audio thread owns this object.
/// After initialization, render(into:) does not allocate, lock, wait, log, read files,
/// decode MIDI or call any Apple host API. Phrase preparation is strictly outside it.
public final class RealtimeSinger {
    private let prepared: RealtimePreparedPhrase
    private let attackCoefficient: Double
    private let releaseCoefficient: Double
    private let pressureCoefficient: Double
    private let pitchCoefficient: Double
    private let breathCoefficient: Double
    private let vibratoDepthRatio: Double
    private let vibratoStep: Double
    private let vibratoStartFrames: Int
    private let vibratoRiseFrames: Int
    private var eventCursor = 0
    private var position = 0
    private var voice = Glottis(midiPitch: 60, sampleRate: 48_000)
    private var consonant: ThreeFormants?
    private var vowel: ThreeFormants?
    private var lastSyllable = -1
    private var pitch = -1
    private var isGated = false
    private var envelope = 0.0
    private var velocity = 0.0
    private var targetPressure = 1.0
    private var pressureGain = 1.0
    private var pitchTarget = 0.0
    private var smoothedIncrement = 0.0
    private var baseIncrement = 0.0
    private var breathTarget = 0.0
    private var breathGain = 0.0
    private var vibratoPhase = 0.0
    private var noiseState: UInt32 = 0x1357_9BDF
    private var previousNoise = 0.0
    private var elapsedArticulation = 0
    private var onsetType: UInt8 = 0
    private let onsetDelay: Int
    private let onsetTransition: Int

    public var framesRendered: Int { position }
    public var isFinished: Bool { position >= prepared.frameCount }
    public private(set) var articulationsStarted = 0
    /// Diagnostics sampled outside the callback; pitch is tracked independently from vowel formants.
    public var currentFundamentalHz: Double { voice.increment * Double(prepared.sampleRate) }
    public var currentBreathLevel: Double { breathGain }

    public init(prepared: RealtimePreparedPhrase) {
        self.prepared = prepared
        let rate = Double(prepared.sampleRate)
        attackCoefficient = 1 - exp(-1 / (0.008 * rate))
        releaseCoefficient = 1 - exp(-1 / (0.065 * rate))
        pressureCoefficient = 1 - exp(-1 / (0.012 * rate))
        pitchCoefficient = 1 - exp(-1 / (0.018 * rate))
        breathCoefficient = 1 - exp(-1 / (0.025 * rate))
        vibratoDepthRatio = pow(2, prepared.vibratoCents / 1200) - 1
        vibratoStep = 2 * Double.pi * 5.3 / rate
        vibratoStartFrames = Int((0.18 * rate).rounded())
        vibratoRiseFrames = max(1, Int((0.20 * rate).rounded()))
        onsetDelay = Int((0.022 * rate).rounded())
        onsetTransition = max(1, Int((0.09 * rate).rounded()))
        voice = Glottis(midiPitch: 60, sampleRate: rate)
    }

    /// Reset for a new scored performance. Not an audio-callback operation.
    public func reset() {
        eventCursor = 0
        position = 0
        lastSyllable = -1
        articulationsStarted = 0
        pitch = -1
        isGated = false
        envelope = 0
        velocity = 0
        targetPressure = 1
        pressureGain = 1
        pitchTarget = 0
        smoothedIncrement = 0
        baseIncrement = 0
        breathTarget = 0
        breathGain = 0
        vibratoPhase = 0
        noiseState = 0x1357_9BDF
        previousNoise = 0
        elapsedArticulation = 0
        onsetType = 0
        consonant = nil
        vowel = nil
        voice.phase = 0
    }

    @inline(__always) private func consume(_ action: VoiceAction) {
        switch action {
        case .noteOn(let syllableIndex, let nextPitch, let increment, let nextVelocity, let advance):
            if advance || syllableIndex != lastSyllable {
                articulationsStarted += 1
                consonant = prepared.voices[syllableIndex].consonant
                vowel = prepared.voices[syllableIndex].vowel
                onsetType = prepared.voices[syllableIndex].onset
                elapsedArticulation = 0
                envelope = 0
                voice.phase = 0
                voice.increment = increment
                smoothedIncrement = increment
                vibratoPhase = 0
                breathTarget = 0
                breathGain = 0
                pressureGain = 1
                targetPressure = 1
            }
            baseIncrement = increment
            pitchTarget = increment
            velocity = 0.55 + 0.45 * nextVelocity
            pitch = nextPitch
            lastSyllable = syllableIndex
            isGated = true
        case .noteOff(let endingPitch):
            if pitch == endingPitch { isGated = false }
        case .pressure(let notePitch, let normalized):
            if pitch == notePitch { targetPressure = 0.35 + 1.30 * normalized }
        case .pitchBend(let notePitch, let multiplier):
            if pitch == notePitch { pitchTarget = baseIncrement * multiplier }
        case .breath(let notePitch, let normalized):
            if pitch == notePitch { breathTarget = normalized }
        }
    }

    @inline(__always) private func nextSample() -> Float {
        if position >= prepared.frameCount { return 0 }
        while eventCursor < prepared.events.count && prepared.events[eventCursor].frame <= position {
            consume(prepared.events[eventCursor].action)
            eventCursor += 1
        }
        position += 1
        if isGated {
            envelope += (1 - envelope) * attackCoefficient
        } else {
            envelope += (0 - envelope) * releaseCoefficient
        }
        pressureGain += (targetPressure - pressureGain) * pressureCoefficient
        breathGain += (breathTarget - breathGain) * breathCoefficient
        smoothedIncrement += (pitchTarget - smoothedIncrement) * pitchCoefficient
        var instantaneous = smoothedIncrement
        if vibratoDepthRatio > 0 && elapsedArticulation > vibratoStartFrames {
            let elapsed = elapsedArticulation - vibratoStartFrames
            let fade = min(1.0, Double(elapsed) / Double(vibratoRiseFrames))
            instantaneous *= 1 + vibratoDepthRatio * fade * sin(vibratoPhase)
        }
        vibratoPhase += vibratoStep
        if vibratoPhase >= 2 * Double.pi { vibratoPhase -= 2 * Double.pi }
        voice.increment = instantaneous
        guard envelope > 0.00001, var onset = consonant, var sustain = vowel else { return 0 }
        let source = voice.sample()
        let delay: Int
        let transition: Int
        if prepared.articulation == .articulated {
            // Voiced bilabial /m/ and alveolar /n/ need longer closed resonant onsets.
            delay = onsetType == 1 ? Int(Double(prepared.sampleRate) * 0.065) :
                    (onsetType == 2 ? Int(Double(prepared.sampleRate) * 0.050) : onsetDelay)
            transition = onsetType == 0 ? onsetTransition : Int(Double(prepared.sampleRate) * 0.070)
        } else {
            delay = onsetDelay
            transition = onsetTransition
        }
        let ratio = Double(elapsedArticulation - delay) / Double(max(1, transition))
        let clipped = min(1, max(0, ratio))
        let mixed = clipped * clipped * (3 - 2 * clipped)
        let onsetGain = prepared.articulation == .articulated ? 0.78 : 0.65
        let signal = onset.filter(source) * (1 - mixed) * onsetGain + sustain.filter(source) * mixed
        // Deterministic non-voiced airflow component driven by standard MIDI2 Breath CC2.
        // Noise state is scalar and never allocates on the audio thread.
        var air = 0.0
        if breathGain > 0.00001 {
            noiseState ^= noiseState << 13
            noiseState ^= noiseState >> 17
            noiseState ^= noiseState << 5
            let white = Double(noiseState & 0xffff) / 32767.5 - 1
            air = (white - previousNoise) * breathGain * 0.12
            previousNoise = white
        }
        if prepared.articulation == .articulated && onsetType != 0 &&
           elapsedArticulation >= delay && elapsedArticulation < delay + transition {
            // A bounded, deterministic nasal-to-vowel release transient; never a
            // synthetic fricative replacing the voiced /m/ or /n/ murmur.
            let window = sin(Double.pi * clipped)
            noiseState ^= noiseState << 13
            noiseState ^= noiseState >> 17
            noiseState ^= noiseState << 5
            let white = Double(noiseState & 0xffff) / 32767.5 - 1
            let transient = (white - previousNoise) * window
            air += transient * (onsetType == 2 ? 0.035 : 0.015)
            previousNoise = white
        }
        consonant = onset
        vowel = sustain
        elapsedArticulation += 1
        return Float((signal + air) * envelope * velocity * pressureGain * 0.8)
    }

    /// Hard real-time inner loop. The caller owns a preallocated Float buffer.
    public func render(into output: UnsafeMutableBufferPointer<Float>) {
        for index in output.indices {
            output[index] = nextSample()
        }
    }

    /// Portable offline witness of exactly the same inner loop.
    public func renderOffline(blockFrames: Int = 256) -> RenderedSound {
        precondition(blockFrames > 0 && blockFrames <= 8192)
        reset()
        var pcm = [Float](repeating: 0, count: prepared.frameCount)
        var scratch = [Float](repeating: 0, count: blockFrames)
        var offset = 0
        while offset < pcm.count {
            let count = min(blockFrames, pcm.count - offset)
            scratch.withUnsafeMutableBufferPointer { ptr in
                render(into: UnsafeMutableBufferPointer(start: ptr.baseAddress, count: count))
            }
            for index in 0..<count { pcm[offset + index] = scratch[index] }
            offset += count
        }
        return RenderedSound(sampleRate: prepared.sampleRate, samples: pcm)
    }
}
