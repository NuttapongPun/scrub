// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Scrub",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Scrub",
            path: "Sources/Scrub"
        )
    ]
)
