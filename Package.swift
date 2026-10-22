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
    // NEW in Phase 14cd: the two SDKs sync uses (D-96). supabase-swift is
    // pinned to the version spike 1 built under xtool. ClerkKit comes from
    // the copy in Vendor/ (port/tools/vendor-clerk.sh), because xtool can't
    // build the String Catalogs in the original.
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", exact: "2.55.4"),
        .package(path: "Vendor/clerk-ios"),
    ],
    targets: [
        .target(
            name: "ClassPing",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "ClerkKit", package: "clerk-ios"),
            ]
        ),
    ]
)
