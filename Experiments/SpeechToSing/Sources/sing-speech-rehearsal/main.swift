import Foundation
import SingVoice
import SingMIDI2
import SingSpeechExperiment

// Four explicit arguments. The speech WAV and its separate provenance /
// phonetic-boundary manifest must already exist; NO network or TTS is called.
// Output MUST stay in a temporary path. No author approval is inferred.
do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 4 || (args.count == 6 && args[4] == "--natural-prelude-ms") else {
        fputs("usage: sing-speech-rehearsal phrase.json captured-speech.wav aligned-source.json /tmp/sung-private.wav [--natural-prelude-ms 50..320]\n", stderr)
        exit(2)
    }
    let prelude = args.count == 6 ? (Int(args[5]) ?? -1) : 0
    let destination = URL(fileURLWithPath: args[3]).standardizedFileURL
    let path = destination.path
    guard (path.hasPrefix("/tmp/") || path.hasPrefix("/private/tmp/")),
          destination.pathExtension.lowercased() == "wav" else {
        throw SingError.invalid("Private rehearsal outputs must be WAV under /tmp; never Git/public assets")
    }
    let score = try JSONDecoder().decode(PhraseDocument.self,
        from: Data(contentsOf: URL(fileURLWithPath: args[0])))
    let source = try JSONDecoder().decode(SpeechSourceManifest.self,
        from: Data(contentsOf: URL(fileURLWithPath: args[2])))
    let wav = try PrivateSpeechWav.read(url: URL(fileURLWithPath: args[1]),
                                         expectedSHA256: source.sourceWavSHA256)
    // One genuine typed MIDI2 UMP score, shared with the procedural baseline.
    let events = try SingMIDI2Score.compile(score)
    let notes = try SingMIDI2Score.decode(score, events: events)
    let (output, report) = try PrivateSpeechSinger.render(
        document: score, performedNotes: notes, speech: wav, manifest: source,
        naturalPreludeMilliseconds: prelude)
    try WaveWriter.write(output, to: destination)
    let json = JSONEncoder()
    json.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try json.encode(report), as: UTF8.self))
} catch {
    fputs("sing-speech-rehearsal: \(error)\n", stderr)
    exit(1)
}
