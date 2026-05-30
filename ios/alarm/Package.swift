// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "alarm",
    platforms: [.iOS("13.0")],
    products: [
        .library(name: "alarm-alarm", targets: ["alarm"]),
    ],
    targets: [
        .target(
            name: "alarm",
            resources: [.process("Resources/default.m4a")]
        ),
    ]
)
