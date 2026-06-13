// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "BearTodoMenuBar",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "BearTodoMenuBar",
            path: "Sources/BearTodoMenuBar",
            exclude: ["Resources/Info.plist"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
