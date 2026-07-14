// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Obsido",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Pinned pre-1.11: newer versions use #Preview macros, which cannot compile
        // without Xcode's preview plugin (this machine builds with CLT only).
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "Obsido",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/Obsido"
        ),
        .testTarget(
            name: "ObsidoTests",
            dependencies: ["Obsido"],
            path: "Tests/ObsidoTests"
        ),
    ]
)
