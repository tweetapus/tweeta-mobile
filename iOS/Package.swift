// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Tweeta",
  platforms: [
    .iOS(.v17)
  ],
  products: [
    .library(name: "Tweeta", targets: ["Tweeta"])
  ],
  targets: [
    .target(name: "Tweeta")
  ]
)
