// swift-tools-version: 5.9
import PackageDescription

// Explicitly isolated offline research target: production Sing remains unchanged.
// midi2sampler is an immutable source dependency, not copied into Sing.
let package = Package(
    name: "SingSpeechExperiment",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SingSpeechExperiment", targets: ["SingSpeechExperiment"]),
        .executable(name: "sing-speech-rehearsal", targets: ["SingSpeechRehearsal"])
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/Fountain-Coach/midi2sampler.git",
                 revision: "64aaed8613a1f8eff0fc8bdb76656688848b0f87")
    ],
    targets: [
        .target(name: "SingSpeechExperiment",
                dependencies: [
                    .product(name: "SingVoice", package: "sing"),
                    .product(name: "SingMIDI2", package: "sing"),
                    .product(name: "Midi2SamplerDSP", package: "midi2sampler")
                ],
                path: "Sources/SingSpeechExperiment"),
        .executableTarget(name: "SingSpeechRehearsal",
                          dependencies: ["SingSpeechExperiment", .product(name: "SingVoice", package: "sing"),
                                         .product(name: "SingMIDI2", package: "sing")],
                          path: "Sources/sing-speech-rehearsal"),
        .testTarget(name: "SingSpeechExperimentTests",
                    dependencies: ["SingSpeechExperiment", .product(name: "SingVoice", package: "sing"),
                                   .product(name: "SingMIDI2", package: "sing")],
                    path: "Tests/SingSpeechExperimentTests")
    ]
)
