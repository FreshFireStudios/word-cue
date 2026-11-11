// swift-tools-version: 5.9
// WordCueKit: the engine shared by Word Cue (and later Word Cue Lab).
// No UI and no microphone code in here, so it can be unit tested on its own.
import PackageDescription

let package = Package(
    name: "WordCueKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WordCueKit", targets: ["WordCueKit"])
    ],
    targets: [
        .target(
            name: "WordCueKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WordCueKitTests",
            dependencies: ["WordCueKit"],
            resources: [.process("Resources")]
        )
    ]
)
