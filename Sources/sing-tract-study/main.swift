import Foundation
import SingVoice

// A bounded observation aid, not a live instrument admission or natural-speech claim.
// The underlying SingVocalTract runs indefinitely until its caller stops it.
do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 1 else {
        fputs("usage: sing-tract-study output-directory\n", stderr)
        exit(2)
    }
    let directory = URL(fileURLWithPath: args[0], isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let states: [(String, SingTractControls)] = [
        ("open-breath", .openBreath()),
        ("narrow-breath", .narrowBreath()),
        ("phonation", .phonation())
    ]

    var entries: [[String: Any]] = []
    for (name, state) in states {
        let instrument = try SingVocalTract(initial: state)
        let audio = try instrument.capture(frames: 48_000 * 3)
        let output = directory.appendingPathComponent(name + ".wav")
        try WaveWriter.write(audio, to: output)
        entries.append([
            "name": name, "path": output.path,
            "sampleRate": audio.sampleRate, "frames": audio.samples.count,
            "rms": audio.rms, "peak": audio.peak,
            "synthetic": true, "humanAuditionAccepted": false,
            "physiologicalMeasurement": false, "release": "not-admitted"
        ])
    }

    let instrument = try SingVocalTract(initial: .openBreath())
    var timeline = try instrument.capture(frames: 48_000 * 2).samples
    instrument.setControls(.narrowBreath())
    timeline.append(contentsOf: try instrument.capture(frames: 48_000 * 2).samples)
    instrument.setControls(.phonation())
    timeline.append(contentsOf: try instrument.capture(frames: 48_000 * 2).samples)
    instrument.setControls(.silence())
    timeline.append(contentsOf: try instrument.capture(frames: 48_000).samples)

    let passage = RenderedSound(sampleRate: 48_000, samples: timeline)
    let passageFile = directory.appendingPathComponent("breath-to-voice.wav")
    try WaveWriter.write(passage, to: passageFile)
    entries.append([
        "name": "breath-to-voice", "path": passageFile.path,
        "sampleRate": passage.sampleRate, "frames": passage.samples.count,
        "rms": passage.rms, "peak": passage.peak,
        "gesture": "continuous open breath → narrow breath → phonation → silence",
        "humanAuditionAccepted": false, "release": "not-admitted"
    ])

    let receipt: [String: Any] = [
        "schema": "sing.tract.study.v1",
        "renderer": "SingVoice.SingVocalTract",
        "noiseSeed": "0x4B6D1C27",
        "voiceBank": "original-synthetic-no-licensed-recording",
        "sourcePhysiology": "source-filter-approximation-not-measured-human-tract",
        "sampleRate": 48_000,
        "results": entries,
        "developerSourceVerificationRequired": true,
        "publicRelease": false
    ]
    let json = try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
    let receiptFile = directory.appendingPathComponent("tract-study.json")
    try json.write(to: receiptFile)
    print(String(decoding: json, as: UTF8.self))
} catch {
    fputs("sing-tract-study: \(error)\n", stderr)
    exit(1)
}
