// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "sns-to-slack-lambda",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .executable(name: "SNSToSlack", targets: ["SNSToSlack"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime", from: "0.2.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.0.0")
    ],
    targets: [
        .target(name: "SNSToSlack", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ])
    ]
)
