// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Blip",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(name: "Blip", targets: ["Blip"]),
    .executable(name: "blip", targets: ["BlipCLI"]),
    // A C interface to Blip for hosts that are not Swift (Rust, C, C++): libBlipC.a.
    .library(name: "BlipC", type: .static, targets: ["BlipC"]),
  ],
  targets: [
    .target(name: "Blip"),
    .target(name: "BlipC", dependencies: ["Blip"]),
    .executableTarget(name: "BlipCLI", dependencies: ["Blip"]),
    .testTarget(name: "BlipTests", dependencies: ["Blip"]),
  ]
)
