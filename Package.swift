// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "discord-webhook",
    platforms: [
        .iOS(.v13),
        .macOS(.v12),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "discord-webhook",
            targets: ["discord-webhook"]
        )
    ],
    targets: [
        .target(
            name: "discord-webhook"
        )
    ]
)
