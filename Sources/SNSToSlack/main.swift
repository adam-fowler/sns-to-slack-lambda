import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import NIO
import NIOHTTP1

enum SNSToSlackError: Error {
    case noSlackHookURL
    case httpError(NIOHTTP1.HTTPResponseStatus)
}

extension SNSToSlackError: CustomStringConvertible {
    var description: String {
        switch self {
        case .noSlackHookURL:
            return "SLACK_HOOK_URL environment variable has not been set"
        case .httpError(let error):
            return "Request to hook returned http status \(error.code)"
        }
    }
}

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

class SNSToSlackHandler: LambdaHandler {
    typealias In = SNS.Event
    typealias Out = Void

    var httpClient: HTTPClient
    
    init(eventLoop: EventLoop) {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoop))
    }
    
    deinit {
        try? self.httpClient.syncShutdown()
    }
    
    func postMessage(_ message: String, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        guard let slackHookUrl = Lambda.env("SLACK_HOOK_URL") else { return eventLoop.makeFailedFuture(SNSToSlackError.noSlackHookURL) }
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
                    guard (200..<300).contains(result.status.code) else { throw SNSToSlackError.httpError(result.status) }
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
    
    func handle(context: Lambda.Context, payload: SNS.Event, callback: @escaping (Result<Out, Error>) -> Void) {
        let message = formatMessage(from: payload.records[0].sns)
        let futureResult = postMessage(message, on: context.eventLoop)
        futureResult.whenComplete { result in
            switch result {
            case .success:
                context.logger.info("Success!")
            case .failure(let error):
                context.logger.error("\(error)")
            }
            callback(result)
        }
    }
    
}
