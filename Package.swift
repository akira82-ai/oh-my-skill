// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OhMySkill",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "OhMySkill",
            dependencies: ["HotKey"],
            path: "src"
        )
    ]
)
