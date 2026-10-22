// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QRnesto",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "QRCore"),
        .executableTarget(name: "QRnesto", dependencies: ["QRCore"]),
    ] 
)
