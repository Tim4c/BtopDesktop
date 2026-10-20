// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BtopDesktop",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "BtopDesktop", targets: ["BtopDesktop"])
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", exact: "1.19.0")
    ],
    targets: [
        .target(name: "NativePTYSupport"),
        .executableTarget(
            name: "BtopDesktop",
            dependencies: ["NativePTYSupport",
                           .product(name: "SwiftTerm", package: "SwiftTerm")],
            path: "Sources/BtopDesktop",
            linkerSettings: [
                .linkedFramework("AppKit")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "BtopDesktopTests",
            dependencies: ["BtopDesktop"],
            path: "Tests/BtopDesktopTests",
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        )
    ]
)
