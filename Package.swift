// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YMM4M",
    // YMM4M targets macOS 26 (Tahoe) on Apple Silicon. The runtime bootstrap,
    // Rosetta 2 x86_64 Wine/DXMT path, and DXMT Metal bridge are only validated
    // there; older systems are refused at launch rather than silently degraded.
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "YMM4MCore", targets: ["YMM4MCore"]),
        .library(name: "YMM4MProtocol", targets: ["YMM4MProtocol"]),
        .executable(name: "YMM4M", targets: ["YMM4MApp"]),
        .executable(name: "YMM4MEncoder", targets: ["YMM4MEncoder"]),
        .executable(name: "YMM4MContractTests", targets: ["YMM4MContractTests"]),
    ],
    targets: [
        .target(
            name: "YMM4MProtocol",
            path: "bridge/Protocol/Sources/YMM4MProtocol"
        ),
        .target(
            name: "YMM4MCore",
            dependencies: ["YMM4MProtocol"],
            path: "app/YMM4M",
            exclude: ["App", "Resources"]
        ),
        .executableTarget(
            name: "YMM4MApp",
            dependencies: ["YMM4MCore"],
            path: "app/YMM4M/App"
        ),
        .executableTarget(
            name: "YMM4MEncoder",
            dependencies: ["YMM4MProtocol"],
            path: "bridge/NativeEncoder/Sources/YMM4MEncoder"
        ),
        .executableTarget(
            name: "YMM4MContractTests",
            dependencies: ["YMM4MCore", "YMM4MProtocol"],
            path: "tests/contracts"
        ),
    ]
)
