// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MetroSeaGlass",
    platforms: [.iOS("26.0")],
    products: [.library(name: "MetroSeaGlass", targets: ["MetroSeaGlass"])],
    targets: [.target(name: "MetroSeaGlass")]
)
