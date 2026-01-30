// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OhMySkill",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OhMySkill",
            dependencies: ["Yams"],
            path: "src"
        )
    ]
)
