import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import NIO
import NIOHTTP1

#if DEBUG
try Lambda.withLocalServer {
    Lambda.run { eventLoop in
        return SNSToSlackHandler(eventLoop: eventLoop)
    }
}
#else
Lambda.run { eventLoop in
    return SNSToSlackHandler(eventLoop: eventLoop)
}
#endif

class SNSToSlackHandler: EventLoopLambdaHandler {
    typealias In = SNS.Event
    typealias Out = Void

    enum Error: Swift.Error {
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

    var httpClient: HTTPClient
    
    init(eventLoop: EventLoop) {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoop))
    }
    
    deinit {
        try? self.httpClient.syncShutdown()
    }
    
    func postMessage(_ message: String, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        guard let slackHookUrl = Lambda.env("SLACK_HOOK_URL") else { return eventLoop.makeFailedFuture(Error.noSlackHookURL) }
        do {
            let json = ["text": message]
            let body = try JSONEncoder().encode(json)
            let request = try HTTPClient.Request(
                url: slackHookUrl,
                method: .POST,
                headers: ["Content-Type": "application/json"],
                body: .data(body))
            return httpClient.execute(request: request, deadline: .now() + .seconds(15))
                .flatMapThrowing { result in
                    guard (200..<300).contains(result.status.code) else { throw Error.httpError(result.status) }
            }
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    func formatMessage(from message: SNS.Message) -> String {
        var text = "*From:* \(message.topicArn)\n"
        if let subject = message.subject {
            text += "*Subject:* \(subject)\n"
        }
        text += "*Message:* \(message.message)\n"
        return text
    }
    
    func handle(context: Lambda.Context, payload: SNS.Event) -> EventLoopFuture<Void> {
        let message = formatMessage(from: payload.records[0].sns)
        return postMessage(message, on: context.eventLoop)
    }
}
