// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Scrub",
    platforms: [
        .macOS(.v11)
    ],
    targets: [
        .executableTarget(
            name: "Scrub",
            path: "Sources/Scrub"
        ),
        .testTarget(
            name: "ScrubTests",
            dependencies: ["Scrub"],
            path: "Tests/ScrubTests"
        )
    ]
)
