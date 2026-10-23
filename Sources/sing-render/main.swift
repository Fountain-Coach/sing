import Foundation
import SingVoice

// Offline instrument audition, not a MIDI device or an editorial publishing operation.
do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 2 || (args.count == 3 && args[2] == "--no-notes-control") else {
        fputs("usage: sing-render phrase.json audition.wav [--no-notes-control]\n", stderr)
        exit(2)
    }
    let input = try Data(contentsOf: URL(fileURLWithPath: args[0]))
    let phrase = try JSONDecoder().decode(PhraseDocument.self, from: input)
    let muted = args.count == 3
    let audio = try ProceduralSinger.render(phrase, muteNotes: muted)
    try WaveWriter.write(audio, to: URL(fileURLWithPath: args[1]))
    let result: [String: Any] = [
        "renderer": "sing.original.procedural.formants.v0",
        "path": args[1], "sampleRate": audio.sampleRate, "frames": audio.samples.count,
        "durationSeconds": Double(audio.samples.count) / Double(audio.sampleRate),
        "peak": audio.peak, "rms": audio.rms,
        "negativeControl": muted, "audibilityReviewed": false, "release": "not-admitted"
    ]
    let encoded = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(decoding: encoded, as: UTF8.self))
} catch {
    fputs("sing-render: \(error)\n", stderr)
    exit(1)
}
