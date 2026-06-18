// swift-tools-version:5.3
import PackageDescription

// BEGIN KMMBRIDGE VARIABLES BLOCK (do not edit)
let remoteKotlinUrl = "https://maven.pinch.nl/maven/eu/queueup/core-spm/0.0.1-alpha/core-spm-0.0.1-alpha.zip"
let remoteKotlinChecksum = "ee5bbe0eafc45d7bbcf84ce349b1a00cd40e2bb4615c167260a755adca122c78"
let packageName = "QueueUp"
// END KMMBRIDGE BLOCK

let package = Package(
    name: packageName,
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: packageName,
            targets: [packageName]
        ),
    ],
    targets: [
        .binaryTarget(
            name: packageName,
            url: remoteKotlinUrl,
            checksum: remoteKotlinChecksum
        )
        ,
    ]
)