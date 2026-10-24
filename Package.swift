// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TuneCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "TuneCore", targets: ["TuneCore"])
    ],
    targets: [
        .target(
            name: "TuneCore",
            path: "Core/Sources"
        ),
        .testTarget(
            name: "TuneCoreTests",
            dependencies: ["TuneCore"],
            path: "Core/Tests"
        )
    ]
)