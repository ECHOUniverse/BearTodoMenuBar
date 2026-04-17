// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BearTodoMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BearTodoMenuBar",
            path: "Sources"
        )
    ]
)
