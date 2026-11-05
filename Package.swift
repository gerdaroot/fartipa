// swift-tools-version:5.9
// Builds the platform-independent game core so it can be tested without an iOS SDK.
import PackageDescription

let package = Package(
    name: "PoopCore",
    targets: [
        .target(name: "PoopCore", path: "ios/PoopDraw/Core"),
        .target(name: "BikerCore", path: "ios/Biker/Core"),
        .testTarget(name: "BikerCoreTests", dependencies: ["BikerCore"], path: "Tests/BikerCoreTests"),
        .testTarget(name: "PoopCoreTests", dependencies: ["PoopCore"], path: "Tests/PoopCoreTests"),
    ]
)
