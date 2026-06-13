// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "alarm",
    platforms: [.iOS("13.0")],
    products: [
        .library(name: "alarm", targets: ["alarm"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "alarm",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [.process("Resources/default.m4a")]
        ),
    ]
)
