import Foundation
import MIDI2
import SingVoice

/// A transport-neutral, timed MIDI 2.0 Universal MIDI Packet.
/// It contains no Apple MIDI endpoints, host-specific timestamps or lyrics.
public struct TimedSingPacket: Equatable {
    public let atMilliseconds: Int
    public let packet: UmpPacket64
    public init(atMilliseconds: Int, packet: UmpPacket64) {
        self.atMilliseconds = atMilliseconds
        self.packet = packet
    }
}

public enum SingMIDI2Error: Error, CustomStringConvertible {
    case invalid(String)
    public var description: String {
        switch self { case .invalid(let s): return s }
    }
}

/// A strictly in-process adapter to Fountain-Coach/midi2 typed UMP.
/// Text/phonemes are bound locally by the authored score, NEVER inserted into packets.
public enum SingMIDI2Score {
    public static func compile(_ document: PhraseDocument) throws -> [TimedSingPacket] {
        try ProceduralSinger.validate(document)
        let group = Uint4(0)!
        let channel = Uint4(0)!
        var events: [TimedSingPacket] = []
        events.reserveCapacity(document.performance.notes.count * 2)
        for note in document.performance.notes {
            let pitch = Uint7(UInt8(note.pitch))!
            let on = Midi2NoteOn(group: group, channel: channel, note: pitch,
                                 velocity: UInt16(note.velocity16))
            let off = NoteOff(group: group, channel: channel, noteNumber: pitch, velocity: 0)
            let offPacket = off.ump()
            events.append(TimedSingPacket(atMilliseconds: note.onMs, packet: on.ump()))
            events.append(TimedSingPacket(atMilliseconds: note.offMs,
                                         packet: UmpPacket64(word0: offPacket.word0, word1: offPacket.word1)))
        }
        return events
    }

    /// Create a real MIDI 2.0 polyphonic-key-pressure UMP, not a fabricated controller format.
    public static func notePressure(pitch: Int, atMilliseconds: Int,
                                    value: UInt32) throws -> TimedSingPacket {
        guard (0...127).contains(pitch), atMilliseconds >= 0 else {
            throw SingMIDI2Error.invalid("Pressure pitch/time outside allowed range")
        }
        let pressure = PolyPressure(group: Uint4(0)!, channel: Uint4(0)!,
                                    noteNumber: Uint7(UInt8(pitch))!, pressure: value)
        let raw = pressure.ump()
        return TimedSingPacket(atMilliseconds: atMilliseconds,
                               packet: UmpPacket64(word0: raw.word0, word1: raw.word1))
    }

    /// Decode UMP note lifecycle into independently authored phoneme assignments.
    /// Monophonic and one advancing note per syllable; silence and malformed sequences fail closed.
    public static func decode(_ document: PhraseDocument, events: [TimedSingPacket]) throws -> [SingPerformanceNote] {
        try ProceduralSinger.validate(document)
        guard !events.isEmpty else { throw SingMIDI2Error.invalid("No MIDI 2.0 events") }
        struct Active {
            let id: String
            let syllableId: String
            let pitch: Int
            let onMs: Int
            let velocity: Int
            var pressures: [SingPerformanceNote.PressurePoint] = []
        }
        var active: Active?
        var completed: [SingPerformanceNote] = []
        let authored = document.performance.notes
        var lastTime = -1

        for timed in events {
            // The offline demo bounds allocations to a single short rehearsal excerpt.
            guard timed.atMilliseconds >= 0, timed.atMilliseconds <= 60_000 else {
                throw SingMIDI2Error.invalid("Rehearsal timestamp out of bounded range")
            }
            guard timed.atMilliseconds >= lastTime else {
                throw SingMIDI2Error.invalid("Out-of-order packet timestamps")
            }
            lastTime = timed.atMilliseconds
            let packet = timed.packet
            // Validate with our actual imported MIDI2 packet/body types, not raw host MIDI.
            guard let body = Midi2ChannelVoiceBody(ump: packet),
                  body.group.rawValue == 0, body.channel.rawValue == 0 else {
                throw SingMIDI2Error.invalid("Only group 0 / channel 0 MIDI 2.0 channel-voice supported")
            }
            let raw = Ump64(word0: packet.word0, word1: packet.word1)!
            switch body.status {
            case 0x9:
                guard let msg = Midi2NoteOn(ump: packet), msg.velocity > 0,
                      msg.attributeType == .none, msg.attributeData == 0,
                      active == nil, completed.count < authored.count else {
                    throw SingMIDI2Error.invalid("Malformed, overlapping or extra Note On")
                }
                let source = authored[completed.count]
                active = Active(id: source.id, syllableId: source.syllableId,
                                pitch: Int(msg.note.rawValue), onMs: timed.atMilliseconds,
                                velocity: Int(msg.velocity))
            case 0x8:
                guard let msg = NoteOff(ump: raw), msg.attributeType == .none,
                      msg.attributeData == 0, let note = active,
                      Int(msg.noteNumber.rawValue) == note.pitch,
                      timed.atMilliseconds > note.onMs else {
                    throw SingMIDI2Error.invalid("Unmatched, malformed or premature Note Off")
                }
                completed.append(SingPerformanceNote(id: note.id, syllableId: note.syllableId,
                    pitch: note.pitch, onMs: note.onMs, offMs: timed.atMilliseconds,
                    velocity16: note.velocity, pressurePoints: note.pressures))
                active = nil
            case 0xA:
                guard let msg = PolyPressure(ump: raw), var note = active,
                      Int(msg.noteNumber.rawValue) == note.pitch,
                      timed.atMilliseconds <= Int.max - 1 else {
                    throw SingMIDI2Error.invalid("Pressure without the corresponding active note")
                }
                let normalized = Double(msg.pressure) / Double(UInt32.max)
                note.pressures.append(.init(timeMs: timed.atMilliseconds, normalized: normalized))
                active = note
            default:
                throw SingMIDI2Error.invalid("Unsupported MIDI 2.0 channel-voice event: \(body.status)")
            }
        }
        guard active == nil, completed.count == authored.count else {
            throw SingMIDI2Error.invalid("Missing Note Off or incomplete performance")
        }
        return completed
    }

    /// Prepare bounded sample-accurate events and all formant coefficients off the audio thread.
    /// Typed Universal MIDI Packets are decoded here; no Apple MIDI host or transport is involved.
    public static func prepareRealtime(_ document: PhraseDocument, events: [TimedSingPacket],
                                       sampleRate: Int = 48_000) throws -> RealtimePreparedPhrase {
        try RealtimePreparedPhrase(document: document, notes: decode(document, events: events),
                                   sampleRate: sampleRate)
    }

    /// This is an isolated offline PCM rehearsal, not a live MIDI endpoint or sound-card witness.
    public static func rehearse(_ document: PhraseDocument, events: [TimedSingPacket],
                                sampleRate: Int = 48_000) throws -> RenderedSound {
        let performance = try decode(document, events: events)
        return try ProceduralSinger.render(document, sampleRate: sampleRate,
                                           performanceNotes: performance)
    }
}
