//
//  SubscriberRouteCollection.swift
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

import FeedKit
import FluentKit
import Foundation
import SwiftSoup
import Vapor


public protocol SubscriberRouteCollection: RouteCollection {
    
    var path: PathComponent { get }
    
    func subscribe(req: Request) async throws -> Response
    
    func handle(req: Request) async throws -> Response
    
    func payload(req: Request) async throws -> Response
    
    func verify(req: Request) async throws -> Response
    
    func verify(req: Request) async -> Result<Subscription.Verification, Error>
    
    func verify(_ verification: Subscription.Verification, on req: Request) async -> Result<Subscription.Verification, Error>
    
}


extension SubscriberRouteCollection {
    
    public func boot(routes: RoutesBuilder) throws {
        let routesGroup = routes.grouped(path)
        routesGroup.get("subscribe", use: subscribe)
        routesGroup.group("callback") { routeBuilder in
            routeBuilder.group(":id") { subBuilder in
                subBuilder.get(use: verify)
                subBuilder.post(use: handle)
            }
        }
    }
    
    public func subscribe(req: Request) async throws -> Response {
        let requestedTopic = try req.query.get(at: "topic") as String
        guard let (topic, hub) = try await req.client.get(URI(string: requestedTopic)).extractWebSubLinks() else {
            return Response(status: .expectationFailed)
        }
        let subscription = try await self.saveSubscription(
            topic: topic,
            hub: hub,
            callback: req.generateCallbackURLString(),
            state: .unverified,
            on: req
        )
        let hubURI = URI(string: subscription.hub)
        let hubRequest = [
            "hub.callback": subscription.callback,
            "hub.topic": subscription.topic,
            "hub.verify": "sync",
            "hub.mode": "subscribe",
        ]
        if req.application.environment == .testing {
            return try await hubRequest.encodeResponse(status: .ok, for: req)
        }
        let subscribe = try await req.client.post(hubURI) { subscribeRequest in
            return try subscribeRequest.content.encode(hubRequest, as: .urlEncodedForm)
        }
        if subscribe.status != .accepted {
            if let subscribeBody = subscribe.body {
                return Response(status: .expectationFailed, body: .init(buffer: subscribeBody))
            }
            return Response(status: .expectationFailed)
        }
        return Response(status: .ok)
    }
    
    public func handle(req: Request) async throws -> Response {
        switch try await req.validateSubscription() {
        case .success(let request):
            return try await self.payload(req: request)
        case .failure:
            return Response(status: .notAcceptable)
        }
    }
    
    public func verify(req: Request) async throws -> Response {
        return await handle(req, with: self.verify) { attempt in
            Response(status: .accepted, body: .init(stringLiteral: attempt.challenge))
        }
    }
    
    public func verify(req: Request) async -> Result<Subscription.Verification, Error> {
        switch (
            Result { try req.query.decode(SubscriptionVerificationRequest.self) }
                .mapError { _ in return HTTPResponseStatus.badRequest }
        ) {
        case .success(let attempt):
            return await self.verify(attempt, on: req)
        case .failure(let reason):
            return .failure(reason)
        }
    }
    
    public func verify(_ verification: Subscription.Verification, on req: Request) async -> Result<Subscription.Verification, Error> {
        do {
            guard let subscription = try await req.findRelatedSubscription() else {
                return .failure(HTTPResponseStatus.notFound)
            }
            if subscription.topic != verification.topic {
                return self.verification(verification, failure: subscription)
            }
            if [.unverified, .verified].contains(subscription.state) {
                return self.verification(verification, success: subscription)
            } else {
                return self.verification(verification, failure: subscription)
            }
        } catch {
            return .failure(error)
        }
    }
    
}


fileprivate extension SubscriberRouteCollection {
    
    func verification(_ verification: Subscription.Verification, success subscription: SubscriptionModel) -> Result<Subscription.Verification, Error> {
        subscription.state = .verified
        subscription.leaseSeconds = verification.leaseSeconds
        if let unwrappedLeaseSeconds = verification.leaseSeconds {
            subscription.expiredAt = Calendar.current.date(byAdding: .second, value: unwrappedLeaseSeconds, to: Date())
        }
        subscription.lastSuccessfulVerificationAt = Date()
        return .success(verification)
    }
    
    func verification(_ verification: Subscription.Verification, failure subscription: SubscriptionModel) -> Result<Subscription.Verification, Error> {
        subscription.state = .unverified
        subscription.lastUnsuccessfulVerificationAt = Date()
        return .failure(HTTPResponseStatus.notFound)
    }
    
    func saveSubscription(
        topic: String,
        hub: String,
        callback: String,
        state: Subscription.State,
        on req: Request
    ) async throws -> Subscription {
        let subscription = SubscriptionModel(
            topic: topic,
            hub: hub,
            callback: callback,
            state: state
        )
        try await subscription.save(on: req.db)
        return subscription
    }
    
}


// MARK: - Verify Attempt Request

fileprivate struct SubscriptionVerificationRequest: Subscription.Verification {
    
    let mode: Subscription.Verification.Mode
    
    let topic: String
    
    let challenge: String
    
    let leaseSeconds: Int?
    
}


extension SubscriptionVerificationRequest: Codable {
    
    enum CodingKeys: String, CodingKey {
        case mode = "hub.mode"
        case topic = "hub.topic"
        case challenge = "hub.challenge"
        case leaseSeconds = "hub.lease_seconds"
    }
    
}


// MARK: - Utilities Extension

fileprivate extension Request {
    
    func findRelatedSubscription() async throws -> SubscriptionModel? {
        return try await SubscriptionModel.query(on: self.db)
            .filter("callback", .equal, self.extractCallbackURLString())
            .first()
    }
    
    func validateSubscription() async throws -> Result<Request, Error> {
        if try await self.hasValidHeaders() {
            return .success(self)
        }
        if try await self.hasValidContent() {
            return .success(self)
        }
        return .failure(HTTPResponseStatus.notAcceptable)
    }
    
    func hasValidHeaders() async throws -> Bool {
        guard let subscription0 = try await self.findRelatedSubscription() else {
            return false
        }
        guard let subscription1 = self.headers.extractWebSubLinks() else {
            return false
        }
        return subscription0.topic == subscription1.topic && subscription0.hub == subscription1.hub
    }
    
    func hasValidContent() async throws -> Bool {
        guard let subscription0 = try await self.findRelatedSubscription() else {
            return false
        }
        guard let subscription1 = self.body.string?.extractWebSubLinks() else {
            return false
        }
        return subscription0.topic == subscription1.topic && subscription0.hub == subscription1.hub
    }
    
    func generateCallbackURLString() -> String {
        return "\(Environment.get("WEBSUB_HOST") ?? "")\(self.url.path.dropSuffix("/subscribe"))/callback/\(UUID().uuidString)"
    }
    
    func extractCallbackURLString() -> String {
        return "\(Environment.get("WEBSUB_HOST") ?? "")\(self.url.path)"
    }
    
}


// MARK: - String Extensions

fileprivate extension String {
    
    func dropSuffix(_ suffix: String) -> String {
        guard self.hasSuffix(suffix) else { return self }
        return String(self.dropLast(suffix.count))
    }
    
}
