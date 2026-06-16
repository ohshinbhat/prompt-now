// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PromptNow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PromptNow", targets: ["PromptNow"]),
        .executable(name: "PromptNowCoreCheck", targets: ["PromptNowCoreCheck"]),
        .library(name: "PromptNowCore", targets: ["PromptNowCore"])
    ],
    targets: [
        .target(name: "PromptNowCore"),
        .executableTarget(
            name: "PromptNow",
            dependencies: ["PromptNowCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "PromptNowCoreCheck",
            dependencies: ["PromptNowCore"]
        )
    ]
)
