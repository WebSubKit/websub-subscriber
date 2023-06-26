//
//  SubscribeRequest + Parser.swift
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


extension SubscribeRequest: RequestParser {
    
    public typealias ParsedType = (Subscription, SubscriptionVerificationMode)
    
    public func parse(on req: Vapor.Request, then: @escaping ((Subscription, SubscriptionVerificationMode)) async throws -> Response) async throws -> Response {
        switch await self.parse(on: req) {
        case .success((let subscription, let mode)):
            return try await then((subscription, mode))
        case .failure(let reason):
            return try await reason.encodeResponse(for: req)
        }
    }
    
    public func parse(on req: Request) async -> Result<(Subscription, Subscription.Verification.Mode), ErrorResponse> {
        do {
            switch self {
            case .subscribeWithNoPreferredHub(let topic, let leaseSeconds, let req):
                let (preferredTopic, preferredHub) = try await self.discover(topic, on: req)
                return try await .success(
                    (
                        Subscriptions.create(
                            topic: preferredTopic,
                            hub: preferredHub,
                            callback: req.generateCallbackURLString(),
                            state: .pendingSubscription,
                            leaseSeconds: leaseSeconds,
                            on: req.db
                        ),
                        .subscribe
                    )
                )
            case .subscribeWithPreferredHub(let topic, let hub, let leaseSeconds, req: let req):
                return try await .success(
                    (
                        Subscriptions.create(
                            topic: topic,
                            hub: hub,
                            callback: req.generateCallbackURLString(),
                            state: .pendingSubscription,
                            leaseSeconds: leaseSeconds,
                            on: req.db
                        ),
                        .subscribe
                    )
                )
            case .unsubscribe(let topic, let callback, let req):
                if let subscription = try await Subscriptions.first(
                    callback: callback,
                    on: req.db
                ) {
                    if subscription.topic != topic {
                        if req.application.environment == .testing {
                            return .failure(
                                ErrorResponse(
                                    code: .notFound,
                                    message: "Invalid topic"
                                )
                            )
                        }
                        return .failure(
                            ErrorResponse(
                                code: .notFound,
                                message: "Not found"
                            )
                        )
                    }
                    subscription.state = .pendingUnsubscription
                    try await subscription.save(on: req.db)
                    return .success((subscription, .unsubscribe))
                }
                let (preferredTopic, preferredHub) = try await self.discover(topic, on: req)
                return try await .success(
                    (
                        Subscriptions.create(
                            topic: preferredTopic,
                            hub: preferredHub,
                            callback: callback,
                            state: .pendingUnsubscription,
                            on: req.db
                        ),
                        .unsubscribe
                    )
                )
            case .failure(let reason, _):
                return .failure(reason)
            }
        } catch {
            if req.application.environment == .testing {
                return .failure(
                    ErrorResponse(
                        code: .notFound,
                        message: error.localizedDescription
                    )
                )
            }
            return .failure(
                ErrorResponse(
                    code: .notFound,
                    message: "Not found"
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
