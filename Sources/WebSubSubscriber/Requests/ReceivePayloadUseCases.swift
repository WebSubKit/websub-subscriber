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

import Vapor


public enum ReceivePayloadUseCases {
    
    case maybeValid(payload: Request, topic: URI, hub: URI)
    
    case invalid
    
}


extension ReceivePayloadUseCases: RequestHandler {
    
    public typealias ResultType = (validPayload: Request, subscription: SubscriptionModel)
    
    public func handle(on req: Request) async -> Result<(validPayload: Request, subscription: SubscriptionModel), ErrorResponse> {
        do {
            switch self {
            case .maybeValid(let payload, let topic, let hub):
                guard let subscription = try await Subscriptions.first(
                    callback: req.urlPath,
                    on: req.db
                ) else {
                    req.logger.info(
                        """
                        Receiving payload: subscription not found
                        request.id   : \(req.id)
                        """
                    )
                    throw HTTPResponseStatus.notFound
                }
                req.logger.info(
                    """
                    Receiving payload: subscription found
                    request.id   : \(req.id)
                    subscription : \(subscription.id?.uuidString ?? "")
                    """
                )
                let subsTopicHub = (topic: URI(string: subscription.topic), hub: URI(string: subscription.hub))
                req.logger.info(
                    """
                    Receiving payload: subscription found & check links
                    request.id   : \(req.id)
                    s.topic      : \(subsTopicHub.topic)
                    s.hub        : \(subsTopicHub.hub)
                    p.topic      : \(topic.string)
                    p.hub        : \(hub.string)
                    """
                )
                if !(topic.string == subsTopicHub.topic.string && hub.host == subsTopicHub.hub.host) {
                    req.logger.info(
                        """
                        Receiving payload: subscription found & links valid
                        request.id   : \(req.id)
                        """
                    )
                    return .success((payload, subscription))
                }
                req.logger.info(
                    """
                    Receiving payload: subscription found but links invalid
                    request.id   : \(req.id)
                    """
                )
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
            request.logger.info(
                """
                Receiving payload: invalid
                request.id   : \(request.id)
                """
            )
            self = .invalid
            return
        }
        request.logger.info(
            """
            Receiving payload: maybe valid
            request.id   : \(request.id)
            topic links  : \(links.topic)
            hub links    : \(links.hub)
            """
        )
        self = .maybeValid(payload: request, topic: links.topic, hub: links.hub)
    }
    
}
