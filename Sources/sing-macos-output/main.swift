import Foundation
import SingVoice
import SingMIDI2

#if os(macOS)
import AVFoundation
import AudioToolbox

// This executable is intentionally outside SingVoice and SingMIDI2.
// AVFoundation is used for PCM playback ONLY. It never opens a MIDI endpoint.
do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 2, ["--probe", "--play"].contains(args[1]) else {
        fputs("usage: sing-macos-output phrase.json --probe | --play\n", stderr)
        exit(2)
    }
    let phrase = try JSONDecoder().decode(PhraseDocument.self,
        from: Data(contentsOf: URL(fileURLWithPath: args[0])))
    let engine = AVAudioEngine()
    let outputFormat = engine.outputNode.inputFormat(forBus: 0)
    let rate = Int(outputFormat.sampleRate.rounded())
    guard (16_000...192_000).contains(rate) else {
        throw SingError.invalid("Physical output reports unsupported sample rate \(rate)")
    }
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: Double(rate), channels: 2,
                                   interleaved: false) else {
        throw SingError.invalid("Could not construct planar stereo output format")
    }
    let packets = try SingMIDI2Score.compile(phrase)
    let plan = try SingMIDI2Score.prepareRealtime(phrase, events: packets, sampleRate: rate)
    let instrument = RealtimeSinger(prepared: plan)

    if args[1] == "--play" {
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioData -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioData)
            guard buffers.count >= 1, let firstData = buffers[0].mData else { return -50 }
            let frames = Int(frameCount)
            let first = firstData.assumingMemoryBound(to: Float.self)
            instrument.render(into: UnsafeMutableBufferPointer(start: first, count: frames))
            if buffers.count > 1 {
                for channel in 1..<buffers.count {
                    guard let destination = buffers[channel].mData else { return -50 }
                    destination.assumingMemoryBound(to: Float.self).update(from: first, count: frames)
                }
            }
            return 0
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        // Protect the author's monitors and avoid assuming a calibrated loudness level.
        engine.mainMixerNode.outputVolume = 0.15
        try engine.start()
        Thread.sleep(forTimeInterval: Double(plan.frameCount) / Double(rate) + 0.4)
        engine.stop()
    }

    let report: [String: Any] = [
        "host": "macOS AVAudioEngine PCM output, separately owned adapter",
        "coreMIDI": false,
        "eventPlane": "Fountain-Coach/midi2 0.12.8 typed UMP; in-process preflight",
        "physicalAudioEngineStarted": args[1] == "--play",
        "samplerate": rate,
        "channels": 2,
        "programmedFrames": plan.frameCount,
        "renderedFrames": instrument.framesRendered,
        "events": plan.eventCount,
        "articulationsStarted": instrument.articulationsStarted,
        "audioHeardByHuman": false,
        "audioCaptureVerified": false,
        "publication": "not-admitted"
    ]
    let encoded = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
    print(String(decoding: encoded, as: UTF8.self))
} catch {
    fputs("sing-macos-output failed: \(error)\n", stderr)
    exit(1)
}
#else
fputs("sing-macos-output only runs on macOS; SingVoice and SingMIDI2 remain portable.\n", stderr)
exit(2)
#endif
