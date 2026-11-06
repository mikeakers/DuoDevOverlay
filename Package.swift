// swift-tools-version: 6.2
import PackageDescription

let isolatedToMainActor: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "DuoDevOverlay",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DuoDevOverlay", targets: ["DuoDevOverlay"]),
    ],
    targets: [
        .target(name: "DuoDevOverlay", swiftSettings: isolatedToMainActor),
        .testTarget(name: "DuoDevOverlayTests",
                    dependencies: ["DuoDevOverlay"],
                    swiftSettings: isolatedToMainActor),
    ],
    swiftLanguageModes: [.v5]
)
