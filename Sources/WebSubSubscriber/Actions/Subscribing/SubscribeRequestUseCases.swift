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

import Vapor


public enum SubscribeRequestUseCases {
    
    case subscribeWithNoPreferredHub(topic: String, leaseSeconds: Int?)
    
    case subscribeWithPreferredHub(topic: String, hub: String, leaseSeconds: Int?)
    
    case unsubscribe(topic: String, callback: String)
        
}


extension SubscribeRequestUseCases: RequestHandler {
    
    public typealias ResultType = (SubscriptionMode, SubscriptionModel)
    
    public func handle(on req: Request) async -> Result<(SubscriptionMode, SubscriptionModel), ErrorResponse> {
        return await self.handle(req: req)
    }
    
}


extension SubscribeRequestUseCases: CommandHandler {
    
    public func handle(on ctx: CommandContext) async -> Result<(SubscriptionMode, SubscriptionModel), ErrorResponse> {
        return await self.handle(ctx: ctx)
    }
    
}


extension SubscribeRequestUseCases {
    
    func handle(req: Request? = nil, ctx: CommandContext? = nil) async -> Result<(SubscriptionMode, SubscriptionModel), ErrorResponse> {
        guard let app = req?.application ?? ctx?.application else {
            return .failure(.init(code: .internalServerError))
        }
        do {
            switch self {
            case .subscribeWithNoPreferredHub(let topic, let leaseSeconds):
                let (preferredTopic, preferredHub) = try await self.discover(topic, on: app)
                return try await .success(
                    (
                        .subscribe,
                        Subscriptions.create(
                            topic: preferredTopic,
                            hub: preferredHub,
                            callback: req?.generateCallbackURLString() ?? self.generateCallbackURLString(on: app),
                            state: .pendingSubscription,
                            leaseSeconds: leaseSeconds,
                            on: app.db
                        )
                    )
                )
            case .subscribeWithPreferredHub(let topic, let hub, let leaseSeconds):
                return try await .success(
                    (
                        .subscribe,
                        Subscriptions.create(
                            topic: topic,
                            hub: hub,
                            callback: req?.generateCallbackURLString() ?? self.generateCallbackURLString(on: app),
                            state: .pendingSubscription,
                            leaseSeconds: leaseSeconds,
                            on: app.db
                        )
                    )
                )
            case .unsubscribe(let topic, let callback):
                if let subscription = try await Subscriptions.first(
                    callback: callback,
                    on: app.db
                ) {
                    if subscription.topic != topic {
                        app.logger.error(
                            """
                            Received unsubscribe request, with error: Invalid topic
                            request.id   : \(req?.id ?? "-")
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
                    try await subscription.save(on: app.db)
                    return .success((.unsubscribe, subscription))
                }
                let (preferredTopic, preferredHub) = try await self.discover(topic, on: app)
                return try await .success(
                    (
                        .unsubscribe,
                        Subscriptions.create(
                            topic: preferredTopic,
                            hub: preferredHub,
                            callback: callback,
                            state: .pendingUnsubscription,
                            on: app.db
                        )
                    )
                )
            }
        } catch {
            app.logger.error(
                """
                Request throwed errors
                request.id   : \(req?.id ?? "-")
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
    
    fileprivate func discover(_ topic: String, on app: Application) async throws -> (topic: String, hub: String) {
        guard let (preferredTopic, preferredHub) = try await app.client.get(URI(string: topic)).extractWebSubLinks() else {
            throw HTTPResponseStatus.notFound
        }
        return (preferredTopic.string, preferredHub.string)
    }
    
    fileprivate func generateCallbackURLString(on app: Application) -> String {
        return "\(app.subscriber.host)/callback/\(UUID().uuidString)"
    }
    
}
