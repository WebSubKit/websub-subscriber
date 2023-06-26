//
//  SubscribeRequestUseCases.swift
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


public enum SubscribeRequestUseCases {
    
    case subscribeWithNoPreferredHub(topic: String, leaseSeconds: Int?, req: Request)
    
    case subscribeWithPreferredHub(topic: String, hub: String, leaseSeconds: Int?, req: Request)
    
    case unsubscribe(topic: String, callback: String, req: Request)
        
}


extension SubscribeRequestUseCases: RequestHandler {
    
    public typealias ResultType = (SubscriptionMode, any Subscription & Model)
    
    public func handle(on req: Request) async -> Result<(SubscriptionMode, any Subscription & Model), ErrorResponse> {
        do {
            switch self {
            case .subscribeWithNoPreferredHub(let topic, let leaseSeconds, let req):
                let (preferredTopic, preferredHub) = try await self.discover(topic, on: req)
                return try await .success(
                    (
                        .subscribe,
                        Subscriptions.create(
                            topic: preferredTopic,
                            hub: preferredHub,
                            callback: req.generateCallbackURLString(),
                            state: .pendingSubscription,
                            leaseSeconds: leaseSeconds,
                            on: req.db
                        )
                    )
                )
            case .subscribeWithPreferredHub(let topic, let hub, let leaseSeconds, req: let req):
                return try await .success(
                    (
                        .subscribe,
                        Subscriptions.create(
                            topic: topic,
                            hub: hub,
                            callback: req.generateCallbackURLString(),
                            state: .pendingSubscription,
                            leaseSeconds: leaseSeconds,
                            on: req.db
                        )
                    )
                )
            case .unsubscribe(let topic, let callback, let req):
                if let subscription = try await Subscriptions.first(
                    callback: callback,
                    on: req.db
                ) {
                    if subscription.topic != topic {
                        req.logger.error(
                            """
                            Received unsubscribe request, with error: Invalid topic
                            request.id   : \(req.id)
                            topic on db  : \(subscription.topic)
                            topic on req : \(topic)
                            """
                        )
                        return .failure(
                            ErrorResponse(
                                code: .notFound,
                                message: "Invalid topic"
                            )
                        )
                    }
                    subscription.state = .pendingUnsubscription
                    try await subscription.save(on: req.db)
                    return .success((.unsubscribe, subscription))
                }
                let (preferredTopic, preferredHub) = try await self.discover(topic, on: req)
                return try await .success(
                    (
                        .unsubscribe,
                        Subscriptions.create(
                            topic: preferredTopic,
                            hub: preferredHub,
                            callback: callback,
                            state: .pendingUnsubscription,
                            on: req.db
                        )
                    )
                )
            }
        } catch {
            req.logger.error(
                """
                Request throwed errors
                request.id   : \(req.id)
                err. message : \(error.localizedDescription)
                """
            )
            return .failure(
                ErrorResponse(
                    code: .badRequest,
                    message: error.localizedDescription
                )
            )
        }
    }
    
    private func discover(_ topic: String, on req: Request) async throws -> (topic: String, hub: String) {
        guard let (preferredTopic, preferredHub) = try await req.client.get(URI(string: topic)).extractWebSubLinks() else {
            throw HTTPResponseStatus.notFound
        }
        return (preferredTopic.string, preferredHub.string)
    }
    
}
