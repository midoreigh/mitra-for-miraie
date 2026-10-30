// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MitraKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MitraKit", targets: ["MitraKit"]),
        .library(name: "MitraUI", targets: ["MitraUI"]),
    ],
    targets: [
        /// Device models, the MirAIe cloud client (REST + MQTT) and shared storage.
        .target(name: "MitraKit"),
        /// SwiftUI pieces shared by the app and its widgets, such as the animated AC unit.
        .target(name: "MitraUI", dependencies: ["MitraKit"]),
        .testTarget(name: "MitraKitTests", dependencies: ["MitraKit"]),
    ]
)
