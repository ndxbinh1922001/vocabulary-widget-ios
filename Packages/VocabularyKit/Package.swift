// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VocabularyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "VocabularyKit", targets: ["VocabularyKit"])
    ],
    targets: [
        .target(
            name: "VocabularyKit",
            resources: [.copy("Resources/builtin_words.json")]
        ),
        .testTarget(
            name: "VocabularyKitTests",
            dependencies: ["VocabularyKit"]
        ),
    ]
)
