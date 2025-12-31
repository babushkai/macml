// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Performant3",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Performant3",
            targets: ["Performant3"]
        )
    ],
    dependencies: [
        // MLX Swift - Apple Silicon native ML framework
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.29.0"),
        // GRDB - SQLite database
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        // Swift Crypto for artifact hashing
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "Performant3",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/Performant3",
            resources: [
                .copy("../../Resources/Scripts")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
    ]
)
