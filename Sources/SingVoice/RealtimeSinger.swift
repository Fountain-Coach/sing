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

private struct PhoneticColor {
    let consonant: ThreeFormants
    let vowel: ThreeFormants
}

private enum VoiceAction {
    case noteOn(syllableIndex: Int, pitch: Int, phaseIncrement: Double, velocity: Double, advance: Bool)
    case noteOff(pitch: Int)
    case pressure(pitch: Int, normalized: Double)
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
    fileprivate let voices: [PhoneticColor]
    fileprivate let events: [VoiceEvent]

    public init(document: PhraseDocument, notes: [SingPerformanceNote], sampleRate: Int = 48_000) throws {
        try ProceduralSinger.validate(document)
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
                vowel: ThreeFormants(ProceduralSinger.formants(for: syllable.phonemes[1].symbol), sampleRate: rate))
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
                guard point.timeMs >= note.onMs, point.timeMs <= note.offMs,
                      point.timeMs >= previousPressure,
                      point.normalized.isFinite, (0...1).contains(point.normalized) else {
                    throw SingError.invalid("Invalid timed polyphonic pressure")
                }
                timeline.append(VoiceEvent(frame: Int((Double(point.timeMs) * rate / 1000).rounded()),
                                           priority: 2,
                                           action: .pressure(pitch: note.pitch, normalized: point.normalized)))
                previousPressure = point.timeMs
            }
            previousOff = note.offMs
        }
        timeline.sort {
            $0.frame == $1.frame ? $0.priority < $1.priority : $0.frame < $1.frame
        }
        self.sampleRate = sampleRate
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
    private var elapsedArticulation = 0
    private let onsetDelay: Int
    private let onsetTransition: Int

    public var framesRendered: Int { position }
    public var isFinished: Bool { position >= prepared.frameCount }
    public private(set) var articulationsStarted = 0

    public init(prepared: RealtimePreparedPhrase) {
        self.prepared = prepared
        let rate = Double(prepared.sampleRate)
        attackCoefficient = 1 - exp(-1 / (0.008 * rate))
        releaseCoefficient = 1 - exp(-1 / (0.065 * rate))
        pressureCoefficient = 1 - exp(-1 / (0.012 * rate))
        pitchCoefficient = 1 - exp(-1 / (0.018 * rate))
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
        elapsedArticulation = 0
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
                elapsedArticulation = 0
                envelope = 0
                voice.phase = 0
                voice.increment = increment
                pressureGain = 1
                targetPressure = 1
            }
            pitchTarget = increment
            velocity = 0.55 + 0.45 * nextVelocity
            pitch = nextPitch
            lastSyllable = syllableIndex
            isGated = true
        case .noteOff(let endingPitch):
            if pitch == endingPitch { isGated = false }
        case .pressure(let notePitch, let normalized):
            if pitch == notePitch { targetPressure = 0.35 + 1.30 * normalized }
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
        voice.increment += (pitchTarget - voice.increment) * pitchCoefficient
        guard envelope > 0.00001, var onset = consonant, var sustain = vowel else { return 0 }
        let source = voice.sample()
        let ratio = Double(elapsedArticulation - onsetDelay) / Double(onsetTransition)
        let clipped = min(1, max(0, ratio))
        let mixed = clipped * clipped * (3 - 2 * clipped)
        let signal = onset.filter(source) * (1 - mixed) * 0.65 + sustain.filter(source) * mixed
        consonant = onset
        vowel = sustain
        elapsedArticulation += 1
        return Float(signal * envelope * velocity * pressureGain * 0.8)
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
