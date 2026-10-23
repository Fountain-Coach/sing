// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sing",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "SingVoice", targets: ["SingVoice"]),
        .library(name: "SingMIDI2", targets: ["SingMIDI2"]),
        .executable(name: "sing-render", targets: ["SingRender"]),
        .executable(name: "sing-midi2-rehearsal", targets: ["SingMIDI2Rehearsal"])
    ],
    dependencies: [
        .package(url: "https://github.com/Fountain-Coach/midi2.git", exact: "0.12.8")
    ],
    targets: [
        .target(name: "SingVoice", path: "Sources/SingVoice"),
        .target(name: "SingMIDI2", dependencies: ["SingVoice", .product(name: "MIDI2", package: "midi2")], path: "Sources/SingMIDI2"),
        .executableTarget(name: "SingRender", dependencies: ["SingVoice"], path: "Sources/sing-render"),
        .executableTarget(name: "SingMIDI2Rehearsal", dependencies: ["SingMIDI2", "SingVoice"], path: "Sources/sing-midi2-rehearsal"),
        .testTarget(name: "SingVoiceTests", dependencies: ["SingVoice"], path: "tests/SingVoiceTests"),
        .testTarget(name: "SingMIDI2Tests", dependencies: ["SingMIDI2", "SingVoice", .product(name: "MIDI2", package: "midi2")], path: "tests/SingMIDI2Tests")
    ]
)
