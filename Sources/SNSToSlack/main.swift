import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import NIO
import NIOHTTP1


Lambda.run { context in
    return SNSToSlackHandler(eventLoop: context.eventLoop )
}

struct SNSToSlackHandler: EventLoopLambdaHandler {
    typealias In = SNS.Event
    typealias Out = Void

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
    
    init(eventLoop: EventLoop) {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoop))
    }
    
    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        try? self.httpClient.syncShutdown()
        return context.eventLoop.makeSucceededFuture(())
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
    
    func formatMessage(from message: SNS.Message) throws -> ByteBuffer {
        var text = "*From:* \(message.topicArn)\n"
        if let subject = message.subject {
            text += "*Subject:* \(subject)\n"
        }
        text += "*Message:* \(message.message)\n"
        
        // Slack hook expects json in the format {"text": "your-message"}
        let json = ["text": text]
        let body = try encoder.encode(json, using: allocator)

        return body
    }
    
    /// Handle a single sns message
    func handleMessage(context: Lambda.Context, message: SNS.Message) -> EventLoopFuture<Void> {
        do {
            let body = try formatMessage(from: message)
            return try postMessage(body, on: context.eventLoop)
        } catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }
    
    /// Called by Lambda run. Calls handle message for each message in the supplied payload
    func handle(context: Lambda.Context, event: SNS.Event) -> EventLoopFuture<Void> {
        let returnFutures: [EventLoopFuture<Void>] = event.records.map { return handleMessage(context: context, message: $0.sns) }
        return EventLoopFuture.whenAllSucceed(returnFutures, on: context.eventLoop).map { _ in }
    }
}
