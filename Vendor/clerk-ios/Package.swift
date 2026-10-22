// swift-tools-version: 6.2
// ClerkKit from clerk-ios, vendored by port/tools/vendor-clerk.sh (D-96): the
// upstream manifest cut down to the one target the app uses.
import PackageDescription

let package = Package(
  name: "Clerk",
  defaultLocalization: "en",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [.library(name: "ClerkKit", targets: ["ClerkKit"])],
  targets: [
    .target(
      name: "ClerkKit",
      path: "Sources/ClerkKit",
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
