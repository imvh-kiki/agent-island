// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentIsland",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "AgentIsland",
            path: "AgentIsland",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
