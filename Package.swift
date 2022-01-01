// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-package-info",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "swift-package-info",
            targets: [
                "Run"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            .upToNextMinor(from: "1.0.2")
        ),
        .package(
            url: "https://github.com/tuist/XcodeProj.git",
            .upToNextMinor(from: "8.7.1")
        ),
        .package(
            url: "https://github.com/apple/swift-tools-support-core.git",
            .upToNextMinor(from: "0.2.4")
        ),
        .package(
            name: "HTTPClient",
            url: "https://github.com/marinofelipe/http_client",
            .upToNextMinor(from: "0.0.4")
        )
    ],
    targets: [
        .target(
            name: "Run",
            dependencies: [
                .target(name: "App"),
                .target(name: "Reports"),
                .target(name: "Core"),
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
                .product(
                    name: "SwiftToolsSupport-auto",
                    package: "swift-tools-support-core"
                )
            ]
        ),
        .testTarget(
            name: "RunTests",
            dependencies: [
                .target(name: "Run")
            ]
        ),
        .target(
            name: "App",
            dependencies: [
                .product(
                    name: "XcodeProj",
                    package: "XcodeProj"
                ),
                .product(
                    name: "CombineHTTPClient",
                    package: "HTTPClient"
                ),
                .target(name: "Core")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .target(name: "CoreTestSupport")
            ]
        ),
        .target(
            name: "Reports",
            dependencies: [
                .product(
                    name: "SwiftToolsSupport-auto",
                    package: "swift-tools-support-core"
                ),
                .target(name: "Core")
            ]
        ),
        .testTarget(
            name: "ReportsTests",
            dependencies: [
                .target(name: "Reports"),
                .target(name: "CoreTestSupport")
            ]
        ),
        .target(
            name: "Core",
            dependencies: [
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
                .product(
                    name: "SwiftToolsSupport-auto",
                    package: "swift-tools-support-core"
                )
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                .target(name: "Core"),
                .target(name: "CoreTestSupport")
            ],
            resources: [
                .copy("Resources/package_full.json"),
                .copy("Resources/package_with_multiple_dependencies.json"),
                .copy("Resources/package_with_custom_target_dependency.json"),
                .copy("Resources/package_full_swift_5_5.json")
            ]
        ),
        .target(
            name: "CoreTestSupport",
            dependencies: [
                .target(name: "Core")
            ]
        )
    ]
)
