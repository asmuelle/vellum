// swift-tools-version: 6.0
// Vellum — core domain packages. Zero external dependencies by design:
// product invariant #1 (no page ever leaves the device) means no networking
// stack, and the vault uses the system SQLite3 module directly.
import PackageDescription

let package = Package(
    name: "VellumKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "VellumKit",
            targets: [
                "VellumCore",
                "VellumCapture",
                "VellumParsing",
                "VellumExtraction",
                "VellumReview",
                "VellumVault",
                "VellumTrends",
                "VellumAsk",
                "VellumExplain",
                "VellumDesignSystem",
            ]
        ),
    ],
    targets: [
        // MARK: Production targets

        .target(
            name: "VellumCore",
            path: "Packages/VellumCore/Sources"
        ),
        .target(
            name: "VellumDesignSystem",
            path: "Packages/VellumDesignSystem/Sources"
        ),
        .target(
            name: "VellumCapture",
            dependencies: ["VellumCore"],
            path: "Packages/VellumCapture/Sources"
        ),
        .target(
            name: "VellumParsing",
            dependencies: ["VellumCore"],
            path: "Packages/VellumParsing/Sources"
        ),
        .target(
            name: "VellumExtraction",
            dependencies: ["VellumCore"],
            path: "Packages/VellumExtraction/Sources"
        ),
        .target(
            name: "VellumReview",
            dependencies: ["VellumCore", "VellumDesignSystem"],
            path: "Packages/VellumReview/Sources"
        ),
        .target(
            name: "VellumVault",
            dependencies: ["VellumCore"],
            path: "Packages/VellumVault/Sources",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "VellumTrends",
            dependencies: ["VellumCore", "VellumVault", "VellumDesignSystem"],
            path: "Packages/VellumTrends/Sources"
        ),
        .target(
            name: "VellumAsk",
            dependencies: ["VellumCore", "VellumVault"],
            path: "Packages/VellumAsk/Sources"
        ),
        .target(
            name: "VellumExplain",
            dependencies: ["VellumCore", "VellumVault"],
            path: "Packages/VellumExplain/Sources"
        ),

        // MARK: Test support (fixture loading, repo-wide source scanning for invariant tests)

        .target(
            name: "VellumTestSupport",
            path: "Packages/VellumTestSupport/Sources"
        ),

        // MARK: Test targets

        .testTarget(
            name: "VellumCoreTests",
            dependencies: ["VellumCore", "VellumTestSupport"],
            path: "Packages/VellumCore/Tests"
        ),
        .testTarget(
            name: "VellumCaptureTests",
            dependencies: ["VellumCapture", "VellumTestSupport"],
            path: "Packages/VellumCapture/Tests"
        ),
        .testTarget(
            name: "VellumParsingTests",
            dependencies: ["VellumParsing", "VellumCapture", "VellumTestSupport"],
            path: "Packages/VellumParsing/Tests"
        ),
        .testTarget(
            name: "VellumExtractionTests",
            dependencies: ["VellumExtraction", "VellumParsing", "VellumCapture", "VellumTestSupport"],
            path: "Packages/VellumExtraction/Tests"
        ),
        .testTarget(
            name: "VellumReviewTests",
            dependencies: ["VellumReview", "VellumParsing", "VellumCapture", "VellumTestSupport"],
            path: "Packages/VellumReview/Tests"
        ),
        .testTarget(
            name: "VellumVaultTests",
            dependencies: ["VellumVault", "VellumTestSupport"],
            path: "Packages/VellumVault/Tests"
        ),
        .testTarget(
            name: "VellumTrendsTests",
            dependencies: ["VellumTrends", "VellumTestSupport"],
            path: "Packages/VellumTrends/Tests"
        ),
        .testTarget(
            name: "VellumAskTests",
            dependencies: ["VellumAsk"],
            path: "Packages/VellumAsk/Tests"
        ),
        .testTarget(
            name: "VellumExplainTests",
            dependencies: ["VellumExplain"],
            path: "Packages/VellumExplain/Tests"
        ),
        .testTarget(
            name: "VellumDesignSystemTests",
            dependencies: ["VellumDesignSystem"],
            path: "Packages/VellumDesignSystem/Tests"
        ),
    ]
)
