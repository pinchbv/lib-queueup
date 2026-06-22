// swift-tools-version:5.3
import PackageDescription

// BEGIN KMMBRIDGE VARIABLES BLOCK (do not edit)
let remoteKotlinUrl = "https://maven.pinch.nl/maven/eu/queueup/core-spm/0.0.1-alpha02/core-spm-0.0.1-alpha02.zip"
let remoteKotlinChecksum = "177d9b7d72d7caaeef14a630596bffb707b9c97851e38102460f1205bfd6b644"
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