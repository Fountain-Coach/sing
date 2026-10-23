import Foundation
import SingVoice
import SingMIDI2

// Native, transport-neutral MIDI 2.0 UMP -> procedural voice -> offline PCM rehearsal.
// It does not create or connect to an Apple CoreMIDI endpoint.
do {
    let args = Array(CommandLine.arguments.dropFirst())
    let flags = Array(args.dropFirst(2))
    guard args.count >= 2, flags.allSatisfy({ ["--pressure", "--realtime"].contains($0) }),
          Set(flags).count == flags.count else {
        fputs("usage: sing-midi2-rehearsal phrase.json audition.wav [--pressure] [--realtime]\n", stderr)
        exit(2)
    }
    let pressureRequested = flags.contains("--pressure")
    let realtimeRequested = flags.contains("--realtime")
    let document = try JSONDecoder().decode(PhraseDocument.self,
        from: Data(contentsOf: URL(fileURLWithPath: args[0])))
    var events = try SingMIDI2Score.compile(document)
    if pressureRequested {
        guard document.performance.notes.count > 1 else {
            throw SingMIDI2Error.invalid("Expressive audition requires at least two authored notes")
        }
        let note = document.performance.notes[1]
        let atMs = note.onMs + (note.offMs - note.onMs) / 2
        let pressure = try SingMIDI2Score.notePressure(pitch: note.pitch, atMilliseconds: atMs,
                                                      value: UInt32.max / 9)
        events.append(pressure)
        events.sort { $0.atMilliseconds < $1.atMilliseconds }
    }
    let pcm: RenderedSound
    if realtimeRequested {
        let plan = try SingMIDI2Score.prepareRealtime(document, events: events)
        pcm = RealtimeSinger(prepared: plan).renderOffline(blockFrames: 128)
    } else {
        pcm = try SingMIDI2Score.rehearse(document, events: events)
    }
    try WaveWriter.write(pcm, to: URL(fileURLWithPath: args[1]))
    let result: [String: Any] = [
        "renderer": "sing.original.procedural.formants.v0",
        "eventPlane": "Fountain-Coach/midi2 typed MIDI 2.0 UMP (in process)",
        "transport": "none",
        "coreMIDI": false,
        "packetCount": events.count,
        "noteCount": document.performance.notes.count,
        "perNotePressure": pressureRequested,
        "sampleAccurateRealtimeInnerLoop": realtimeRequested,
        "sampleRate": pcm.sampleRate,
        "frames": pcm.samples.count,
        "rms": pcm.rms, "peak": pcm.peak,
        "audibilityReviewed": false, "release": "not-admitted"
    ]
    let json = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(decoding: json, as: UTF8.self))
} catch {
    fputs("sing-midi2-rehearsal: \(error)\n", stderr)
    exit(1)
}
