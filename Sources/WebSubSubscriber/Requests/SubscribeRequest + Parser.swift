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
    
    public typealias ParsedType = (Subscription, SubscriptionMode)
    
    public init(from req: Request) async {
        switch (
            Result { try req.query.decode(QuerySubscribeRequest.self) }
        ) {
        case .success(let request):
            let mode = request.mode ?? .subscribe
            switch mode {
            case .subscribe:
                if let hub = request.hub {
                    self = .subscribeWithPreferredHub(
                        topic: request.topic,
                        hub: hub,
                        leaseSeconds: request.leaseSeconds,
                        req: req
                    )
                    return
                }
                self = .subscribeWithNoPreferredHub(
                    topic: request.topic,
                    leaseSeconds: request.leaseSeconds,
                    req: req
                )
                return
            case .unsubscribe:
                guard let callback = request.callback else {
                    self = .failure(
                        reason: ErrorResponse(
                            code: .badRequest,
                            message: "Callback should be present on unsubscribe mode"
                        ),
                        req: req
                    )
                    return
                }
                self = .unsubscribe(
                    topic: request.topic,
                    callback: callback,
                    req: req
                )
                return
            }
        case .failure(let reason):
            self = .failure(
                reason: ErrorResponse(
                    code: .badRequest,
                    message: reason.localizedDescription
                ),
                req: req
            )
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


// MARK: - Query Subscribe Request

fileprivate struct QuerySubscribeRequest: Codable {
    
    typealias Mode = SubscriptionMode
    
    let topic: String
    
    let mode: QuerySubscribeRequest.Mode?
    
    let hub: String?
    
    let callback: String?
    
    let leaseSeconds: Int?
    
    enum CodingKeys: String, CodingKey {
        case topic = "topic"
        case mode = "mode"
        case hub = "hub"
        case callback = "callback"
        case leaseSeconds = "lease_seconds"
    }
    
}


extension QuerySubscribeRequest: Content { }
