import MIDI2
import SingVoice

/// An entirely synthetic comparison scenario, not an instrument protocol extension.
/// Author-controlled phoneme identities remain in PhraseDocument; the events use
/// only real MIDI 2.0 channel messages supplied by Fountain-Coach/midi2.
public enum SyntheticSingRehearsal {
    public static func expressed(_ document: PhraseDocument,
                                 startingFrom base: [TimedSingPacket]) throws -> [TimedSingPacket] {
        try ProceduralSinger.validate(document)
        guard document.performance.notes.count > 1 else {
            throw SingMIDI2Error.invalid("Expressive rehearsal requires at least two notes")
        }
        let note = document.performance.notes[1]
        let duration = note.offMs - note.onMs
        guard duration >= 40 else {
            throw SingMIDI2Error.invalid("Expressive rehearsal note too short for controllers")
        }
        let first = note.onMs + duration / 3
        let last = note.onMs + duration * 3 / 4
        guard last + 9 < note.offMs else {
            throw SingMIDI2Error.invalid("Controller exceeds note end")
        }
        var events = base
        events.append(try SingMIDI2Score.pitchBend(semitones: 1.25, atMilliseconds: first))
        events.append(try SingMIDI2Score.breath(normalized: 0.72, atMilliseconds: first + 9))
        events.append(try SingMIDI2Score.pitchBend(semitones: -0.35, atMilliseconds: last))
        events.append(try SingMIDI2Score.breath(normalized: 0.12, atMilliseconds: last + 9))
        // No two synthetic controls share a timestamp, so equal-order ambiguity is avoided.
        events.sort { $0.atMilliseconds < $1.atMilliseconds }
        return events
    }
}
