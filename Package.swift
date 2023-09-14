// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "sns-to-slack-lambda",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "SNSToSlack", targets: ["SNSToSlack"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime", from: "1.0.0-alpha"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events", from: "0.1.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.2.0")
    ],
    targets: [
        .executableTarget(name: "SNSToSlack", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ])
    ]
)
