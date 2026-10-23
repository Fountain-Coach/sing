// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sing",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SingVoice", targets: ["SingVoice"]),
        .executable(name: "sing-render", targets: ["SingRender"])
    ],
    targets: [
        .target(name: "SingVoice", path: "Sources/SingVoice"),
        .executableTarget(name: "SingRender", dependencies: ["SingVoice"], path: "Sources/sing-render"),
        .testTarget(name: "SingVoiceTests", dependencies: ["SingVoice"], path: "tests/SingVoiceTests")
    ]
)
