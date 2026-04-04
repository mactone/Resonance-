// swift-tools-version: 5.9
// NOTE: This Package.swift is for code-editor tooling only.
// To build the iOS app, use the generated Xcode project:
//   brew install xcodegen && xcodegen generate
// Then open Resonance.xcodeproj in Xcode.

import PackageDescription

let package = Package(
    name: "Resonance",
    platforms: [.iOS(.v17)],
    targets: [
        .target(
            name: "Resonance",
            path: "Sources/Resonance",
            exclude: ["Resources"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-disable-access-control"])
            ]
        )
    ]
)
