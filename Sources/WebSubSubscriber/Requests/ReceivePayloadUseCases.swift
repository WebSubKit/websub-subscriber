//
//  ReceivePayloadUseCases.swift
//  
//  Copyright (c) 2023 WebSubKit Contributors
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Fluent
import Vapor


public enum ReceivePayloadUseCases {
    
    case maybeValid(payload: Request, topic: URI, hub: URI)
    
    case invalid
    
}


extension ReceivePayloadUseCases: RequestHandler {
    
    public typealias ResultType = (validPayload: Request, subscription: any Subscription & Model)
    
    public func handle(on req: Request) async -> Result<(validPayload: Request, subscription: any Subscription & Model), ErrorResponse> {
        do {
            switch self {
            case .maybeValid(let payload, let topic, let hub):
                guard let subscription = try await Subscriptions.first(
                    callback: req.urlPath,
                    on: req.db
                ) else {
                    throw HTTPResponseStatus.notFound
                }
                let subsTopicHub = (topic: URI(string: subscription.topic), hub: URI(string: subscription.hub))
                if !(topic.string == subsTopicHub.topic.string && hub.host == subsTopicHub.hub.host) {
                    return .success((payload, subscription))
                }
                throw HTTPResponseStatus.notFound
            case .invalid:
                throw HTTPResponseStatus.notFound
            }
        } catch {
            return .failure(
                ErrorResponse(
                    code: .notFound,
                    message: "Not found"
                )
            )
        }
    }
    
}


extension ReceivePayloadUseCases {
    
    init(from request: Request) {
        guard let links = request.headers.extractWebSubLinks() ?? request.body.string?.extractWebSubLinks() else {
            self = .invalid
            return
        }
        self = .maybeValid(payload: request, topic: links.topic, hub: links.hub)
    }
    
}
