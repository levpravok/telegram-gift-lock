// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GiftLockCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "GiftLockCore", targets: ["GiftLockCore"])],
    targets: [
        .target(name: "GiftLockCore", path: "Source/GiftLock", exclude: ["GiftLockApp.swift", "Assets.xcassets"], sources: ["GiftLockCore.swift"]),
        .testTarget(name: "GiftLockCoreTests", dependencies: ["GiftLockCore"], path: "Tests")
    ]
)
