// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FocusNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "FocusNotch", path: "Sources/FocusNotch")
    ]
)
