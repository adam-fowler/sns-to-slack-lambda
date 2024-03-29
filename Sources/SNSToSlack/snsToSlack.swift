import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import NIOCore
import NIOFoundationCompat
import NIOHTTP1


@main
struct SNSToSlackHandler: EventLoopLambdaHandler {
    typealias Event = SNSEvent
    typealias Output = Void

    enum Error: Swift.Error, CustomStringConvertible {
        case noSlackHookURL
        case httpError(NIOHTTP1.HTTPResponseStatus)

        var description: String {
            switch self {
            case .noSlackHookURL:
                return "SLACK_HOOK_URL environment variable has not been set"
            case .httpError(let error):
                return "Request to hook returned http status \(error.code)"
            }
        }
    }

    let allocator = ByteBufferAllocator()
    let encoder = JSONEncoder()
    var httpClient: HTTPClient
    
    init(context: LambdaInitializationContext) {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(context.eventLoop))
    }
    
    static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Self> {
        return context.eventLoop.makeSucceededFuture(Self(context: context))
    }

    /// Called by Lambda run. Calls handle message for each message in the supplied payload
    func handle(_ event: Event, context: LambdaContext) -> EventLoopFuture<Void> {
        let returnFutures: [EventLoopFuture<Void>] = event.records.map { return handleMessage(context: context, message: $0.sns) }
        return EventLoopFuture.whenAllSucceed(returnFutures, on: context.eventLoop).map { _ in }
    }
    
    func postMessage(_ body: ByteBuffer, on eventLoop: EventLoop) throws -> EventLoopFuture<Void> {
        guard let slackHookUrl = Lambda.env("SLACK_HOOK_URL") else { return eventLoop.makeFailedFuture(Error.noSlackHookURL) }
        let request = try HTTPClient.Request(
            url: slackHookUrl,
            method: .POST,
            headers: ["Content-Type": "application/json"],
            body: .byteBuffer(body))
        return httpClient.execute(request: request, deadline: .now() + .seconds(15))
            .flatMapThrowing { result in
                guard (200..<300).contains(result.status.code) else { throw Error.httpError(result.status) }
        }
    }
    
    func formatMessage(from message: SNSEvent.Message) throws -> ByteBuffer {
        var text = "*From:* \(message.topicArn)\n"
        if let subject = message.subject {
            text += "*Subject:* \(subject)\n"
        }
        text += "*Message:* \(message.message)\n"
        
        // Slack hook expects json in the format {"text": "your-message"}
        let json = ["text": text]
        let body = try encoder.encodeAsByteBuffer(json, allocator: allocator)

        return body
    }
    
    /// Handle a single sns message
    func handleMessage(context: LambdaContext, message: SNSEvent.Message) -> EventLoopFuture<Void> {
        do {
            let body = try formatMessage(from: message)
            return try postMessage(body, on: context.eventLoop)
        } catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }
}
