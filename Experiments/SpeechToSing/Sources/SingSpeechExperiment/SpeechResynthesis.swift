import Foundation
import SingVoice
import Midi2SamplerDSP

/// A *first experimental* formant-conserving pitch-synchronous overlap-add
/// resynthesizer (PSOLA). It reuses fixed-width source vowel grains while
/// controlling the spacing between successive grains from MIDI 2.0 notes.
/// This approximates formant preservation; perceptual fidelity is NOT proven.
public struct SpeechResynthesisReport: Encodable {
    public struct Syllable: Encodable {
        public let id: String
        public let sourcePitchHz: Double
        public let autocorrelation: Double
        public let sourcePulseCount: Int
        public let outputOnsetCount: Int
    }
    public let engine: String
    public let sourceKind: String
    public let sourceSHA256: String
    public let alignmentStatus: String
    public let rendererStatus: String
    public let eventPlane: String
    public let transport: String
    public let coreMIDI: Bool
    public let sampleRate: Int
    public let frames: Int
    public let rms: Double
    public let peak: Double
    public let phonemeRecognition: String
    public let humanIntelligibility: String
    public let publicRelease: String
    public let syllables: [Syllable]
}

public enum SpeechPitch {
    /// Find a comparatively steady 50ms voiced nucleus, not a misleading
    /// 160ms mean over a naturally falling spoken pitch contour.
    /// This remains a pulse proxy, NOT phoneme or qualified pitch recognition.
    public static func estimate(_ audio: [Float], sampleRate: Int,
                                minHz: Double = 100, maxHz: Double = 600)
        -> (hz: Double, confidence: Double, stableStart: Int)? {
        guard sampleRate > 0, audio.count >= sampleRate / 20 else { return nil }
        let downsample = 4
        let rate = Double(sampleRate) / Double(downsample)
        let minLag = max(8, Int(rate / maxHz))
        let maxLag = Int(rate / minHz)
        let windowLength = min(audio.count, sampleRate / 20)
        let step = max(1, sampleRate / 50)
        guard windowLength / downsample > maxLag * 3 else { return nil }
        var windows = [(start: Int, lag: Int, confidence: Double, level: Double)]()
        var highestLevel = 0.0
        for start in stride(from: 0, through: audio.count - windowLength, by: step) {
            var segment = stride(from: start, to: start + windowLength, by: downsample)
                .map { audio[$0] }
            removeDCInPlace(&segment)
            let level = Double(rms(segment))
            guard level >= 0.008 else { continue }
            highestLevel = max(highestLevel, level)
            var scores = [Double](repeating: 0, count: maxLag + 1)
            var top = 0.0
            var topLag = minLag
            for lag in minLag...maxLag {
                var dot = 0.0, xx = 0.0, yy = 0.0
                for i in 0..<(segment.count - lag) {
                    let x = Double(segment[i]), y = Double(segment[i + lag])
                    dot += x * y; xx += x * x; yy += y * y
                }
                let score = dot / sqrt(max(1e-18, xx * yy))
                scores[lag] = score
                if score > top { top = score; topLag = lag }
            }
            guard top >= 0.58 else { continue }
            if maxLag > minLag + 2 {
                for lag in (minLag + 1)..<maxLag {
                    if scores[lag] >= max(0.62, top - 0.06),
                       scores[lag] >= scores[lag - 1],
                       scores[lag] >= scores[lag + 1] {
                        topLag = lag
                        break
                    }
                }
            }
            windows.append((start, topLag, scores[topLag], level))
        }
        guard highestLevel > 0.008 else { return nil }
        // High autocorrelation in a near-silent voice tail should not
        // outrank a well-voiced onset. Preserve original voice dynamics.
        let best = windows.max {
            $0.confidence * sqrt($0.level / highestLevel) <
                $1.confidence * sqrt($1.level / highestLevel)
        }
        guard let selected = best, selected.confidence >= 0.62 else { return nil }
        return (rate / Double(selected.lag), selected.confidence, selected.start)
    }
}

public enum PrivateSpeechSinger {
    private static func hz(_ midiPitch: Int) -> Double {
        440.0 * pow(2.0, Double(midiPitch - 69) / 12.0)
    }

    private static func note(at frame: Int, notes: [SingPerformanceNote],
                             sampleRate: Int) -> SingPerformanceNote {
        let ms = frame * 1000 / sampleRate
        // If frame is inside a written gap, prefer the previous note for the
        // release; the audio must never invent an extra articulation onset.
        for n in notes where ms < n.offMs { return n }
        return notes[notes.count - 1]
    }

    private static func pitch(at frame: Int, notes: [SingPerformanceNote],
                              sampleRate: Int) -> Double {
        let n = note(at: frame, notes: notes, sampleRate: sampleRate)
        let ms = frame * 1000 / sampleRate
        let bend = n.pitchPoints.last(where: { $0.timeMs <= ms })?.semitones ?? 0
        return hz(n.pitch) * pow(2.0, bend / 12.0)
    }

    private static func pulseMarks(_ source: [Float], sampleRate: Int,
                                   start: Int, end: Int, period: Int) -> [Int] {
        guard period >= 8, end - start > 5 * period else { return [] }
        var marks = [Int]()
        let searchRadius = max(2, period / 5)
        var predicted = start + 2 * period
        while predicted + 2 * period < end {
            var mark = predicted
            var maximum = -1.0
            for i in (predicted - searchRadius)...(predicted + searchRadius) {
                let value = abs(Double(source[i]))
                if value > maximum { maximum = value; mark = i }
            }
            if let previous = marks.last, mark <= previous { break }
            marks.append(mark)
            predicted += period
        }
        return marks
    }

    public static func render(document: PhraseDocument,
                              performedNotes: [SingPerformanceNote],
                              speech: DecodedSpeechWav,
                              manifest: SpeechSourceManifest)
        throws -> (RenderedSound, SpeechResynthesisReport) {
        try ProceduralSinger.validate(document)
        let sr = speech.sampleRate
        guard manifest.schema == "sing.speech-source.v1",
              manifest.sampleRate == sr, sr == 48_000,
              manifest.sourceWavSHA256 == speech.sha256,
              manifest.sourceText == document.source.text,
              manifest.release == "not-admitted",
              ["provisional", "independently-verified"].contains(manifest.alignmentStatus),
              !manifest.rightsDeclaration.trimmingCharacters(in: .whitespaces).isEmpty,
              !manifest.sourceModelOrVoice.isEmpty,
              !manifest.sourceKind.isEmpty else {
            throw SingError.invalid("Source identity, alignment, private release, or rights mismatch")
        }
        guard manifest.regions.map(\.syllableId) == document.phrase.syllables.map(\.id),
              performedNotes.count == document.performance.notes.count else {
            throw SingError.invalid("Source phoneme regions or MIDI 2.0 note identities do not match score")
        }
        for (a,b) in zip(performedNotes, document.performance.notes) {
            guard a.id == b.id, a.syllableId == b.syllableId,
                  (0...127).contains(a.pitch), a.onMs >= 0, a.offMs > a.onMs else {
                throw SingError.invalid("Performance note not independently sourced from the score")
            }
        }
        let frameCount = Int(Double(performedNotes.last!.offMs + 400) * Double(sr) / 1000)
        guard frameCount < 10_000_000 else { throw SingError.invalid("Output too long") }
        var output = [Float](repeating: 0, count: frameCount)
        var findings: [SpeechResynthesisReport.Syllable] = []
        var previousEnd = 0
        for region in manifest.regions {
            guard region.onsetStartFrame >= previousEnd,
                  region.onsetStartFrame < region.vowelStartFrame,
                  region.vowelStartFrame + sr / 20 < region.vowelEndFrame,
                  region.vowelEndFrame <= speech.samples.count else {
                throw SingError.invalid("Invalid or non-isolated source phoneme region \(region.syllableId)")
            }
            previousEnd = region.vowelEndFrame
            let notes = performedNotes.filter { $0.syllableId == region.syllableId }
            guard let first = notes.first, let last = notes.last else {
                throw SingError.invalid("Syllable without a performed MIDI 2.0 note")
            }
            let start = Int(Double(first.onMs) * Double(sr) / 1000)
            let end = Int(Double(last.offMs) * Double(sr) / 1000)
            let length = end - start
            guard length >= sr / 10, start >= 0, end <= output.count else {
                throw SingError.invalid("Scored syllable duration invalid")
            }
            let vowel = Array(speech.samples[region.vowelStartFrame..<region.vowelEndFrame])
            guard let detected = SpeechPitch.estimate(vowel, sampleRate: sr) else {
                throw SingError.invalid("No reliable voiced pitch in source nucleus \(region.syllableId)")
            }
            let sourcePeriod = Int((Double(sr) / detected.hz).rounded())
            // Never force one average pulse period across a spoken glissando.
            // Extract repeatable grains from the stable *local* nucleus instead.
            let stableBegin = region.vowelStartFrame + detected.stableStart
            let stableEnd = min(region.vowelEndFrame, stableBegin + sr * 3 / 40)
            let marks = pulseMarks(speech.samples, sampleRate: sr,
                                   start: stableBegin, end: stableEnd, period: sourcePeriod)
            guard marks.count >= 3 else {
                throw SingError.invalid("No stable source pulse landmarks in \(region.syllableId)")
            }
            let nativeOnset = region.vowelStartFrame - region.onsetStartFrame
            let onsetFrames = min(nativeOnset, sr / 5, max(sr / 100, length / 3))
            let crossFrames = min(sr / 40, onsetFrames / 2)
            let vowelBegin = max(0, onsetFrames - crossFrames)
            var accumulated = [Float](repeating: 0, count: length)
            var weights = [Float](repeating: 0, count: length)
            var outCenter = Double(vowelBegin)
            // Proof-of-concept: repeat the same phase-anchored, steady-nucleus
            // grain. Cycling unaligned spoken pulses smeared /mi/ and /na/.
            // Genuine evolving-timbre grains require independent phase matching.
            let referencePulse = marks[marks.count / 2]
            var previousPitch = pitch(at: start + vowelBegin, notes: notes, sampleRate: sr)
            while outCenter < Double(length + sourcePeriod) {
                let center = Int(outCenter.rounded())
                let sourceMark = referencePulse
                let left = max(0, center - sourcePeriod)
                let right = min(length, center + sourcePeriod)
                if left < right {
                    for i in left..<right {
                        let offset = i - center
                        let sampleIndex = sourceMark + offset
                        if sampleIndex >= region.vowelStartFrame,
                           sampleIndex < region.vowelEndFrame {
                            let window = 0.5 + 0.5 * cos(Double.pi * Double(offset) / Double(sourcePeriod))
                            accumulated[i] += Float(Double(speech.samples[sampleIndex]) * window)
                            weights[i] += Float(window)
                        }
                    }
                }
                let targetHz = pitch(at: start + center, notes: notes, sampleRate: sr)
                // Deliberately bounded inter-pulse pitch slew; MIDI2 supplies
                // targets, not a second timing or score representation.
                previousPitch += max(-18, min(18, targetHz - previousPitch))
                outCenter += Double(sr) / previousPitch
            }
            let inputRMS = rms(vowel)
            let level = min(3.0, max(0.4, 0.15 / Double(max(0.001, inputRMS))))
            let endFade = max(1, min(sr / 100, length / 8))
            for i in 0..<length {
                var voiced = Double(weights[i] > 0.1 ? accumulated[i] / weights[i] : 0)
                let vowelGain = i <= vowelBegin ? 0.0 :
                    min(1.0, Double(i - vowelBegin) / Double(max(1, crossFrames)))
                let tail = min(1.0, Double(length - 1 - i) / Double(endFade))
                voiced *= max(0, vowelGain) * max(0, tail) * level
                let onset = i < onsetFrames ?
                    Double(speech.samples[region.onsetStartFrame + i]) * level : 0.0
                let combined: Double
                if i < vowelBegin {
                    combined = onset
                } else if i < onsetFrames {
                    let t = Float(i - vowelBegin) / Float(max(1, crossFrames))
                    let (a,b) = Window.equalPowerScalar(t)
                    combined = Double(a) * onset + Double(b) * voiced
                } else {
                    combined = voiced
                }
                let n = note(at: start + i, notes: notes, sampleRate: sr)
                let ms = (start + i) * 1000 / sr
                let pressure = n.pressurePoints.last(where: { $0.timeMs <= ms })?.normalized
                let volume = (0.6 + 0.4 * Double(n.velocity16) / 65_535.0) *
                    (pressure.map { 0.75 + 0.5 * $0 } ?? 1)
                output[start + i] += Float(combined * volume)
            }
            findings.append(.init(id: region.syllableId,
                                  sourcePitchHz: detected.hz,
                                  autocorrelation: detected.confidence,
                                  sourcePulseCount: marks.count,
                                  outputOnsetCount: 1))
        }
        // Headroom is bounded, rather than hiding corrupted synthesis with
        // a blind per-take normalizer. No file or IO in an audio callback.
        let peak = output.reduce(0.0) { max($0, abs(Double($1))) }
        guard peak.isFinite, peak > 0.001 else {
            throw SingError.invalid("Sampled speech resynthesis is silent or invalid")
        }
        let attenuation = min(1.0, 0.85 / peak)
        if attenuation < 1 {
            for i in output.indices { output[i] *= Float(attenuation) }
        }
        let sound = RenderedSound(sampleRate: sr, samples: output)
        let report = SpeechResynthesisReport(
            engine: "sing.speech.psola.offline.proof.v0",
            sourceKind: manifest.sourceKind,
            sourceSHA256: manifest.sourceWavSHA256,
            alignmentStatus: manifest.alignmentStatus,
            rendererStatus: "offline-resynthesis-not-perceptually-qualified",
            eventPlane: "Fountain-Coach/midi2 typed MIDI 2.0 UMP (in-process)",
            transport: "none", coreMIDI: false,
            sampleRate: sr, frames: output.count, rms: sound.rms, peak: sound.peak,
            phonemeRecognition: "not-performed",
            humanIntelligibility: "unverified",
            publicRelease: "not-admitted", syllables: findings
        )
        return (sound, report)
    }
}
