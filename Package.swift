// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClassPing",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "ClassPing",
            targets: ["ClassPing"]
        ),
    ],
    targets: [
        .target(
            name: "ClassPing"
        ),
    ]
)
