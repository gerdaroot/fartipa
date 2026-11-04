// swift-tools-version:5.9
// Builds the platform-independent game core so it can be tested without an iOS SDK.
import PackageDescription

let package = Package(
    name: "PoopCore",
    targets: [
        .target(name: "PoopCore", path: "ios/PoopDraw/Core"),
        .testTarget(name: "PoopCoreTests", dependencies: ["PoopCore"], path: "Tests/PoopCoreTests"),
    ]
)
