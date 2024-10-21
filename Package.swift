// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "myProject",
    // platforms: [
    //     .macOS(.v10_15)
    // ],

    platforms: [
        .macOS(.v13)  // Limits the tool to macOS 12 or later
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/console-kit", from: "4.1.0")
    ],
    targets: [
        // miinum osx version 10.13
        .executableTarget(
            name: "aarpack",
            dependencies: [
                .product(name: "ConsoleKit", package: "console-kit")
                // .product(name: "Compression", package: "console-kit")
                // .product(name: "Accelerate", package: "console-kit")
            ])
        // .testTarget(name: "myProjectTests", dependencies: ["myProject"]),
    ]
)
