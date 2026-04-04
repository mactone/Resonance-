// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Resonance",
    platforms: [.iOS(.v17)],
    targets: [
        .executableTarget(
            name: "Resonance",
            path: "Sources/Resonance",
            exclude: [],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
