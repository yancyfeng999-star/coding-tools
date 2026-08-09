// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [:]
)
#endif

let package = Package(
    name: "CodingTools",
    dependencies: [
        // Sparkle 2：应用内自动更新（EdDSA 签名 + HTTPS Appcast + GitHub Releases）
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
    ]
)
