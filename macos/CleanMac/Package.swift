// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CleanMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CleanMac", targets: ["CleanMac"])
    ],
    targets: [
        .executableTarget(
            name: "CleanMac",
            path: "Sources",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("SceneKit"),
            ]
        )
    ]
)
