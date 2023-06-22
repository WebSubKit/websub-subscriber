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


public protocol SubscriberRouteCollection:
        RouteCollection,
        PreparingToSubscribe,
        PreparingToUnsubscribe,
        Subscribing,
        Discovering,
        VerifyingToSubscribe,
        VerifyingToUnsubscribe
    {
    
    var path: PathComponent { get }
    
    func setup(routes: RoutesBuilder, middlewares: [Middleware]) throws
    
    func subscribe(req: Request) async throws -> Response
    
    func handle(req: Request) async throws -> Response
    
    func payload(for subscription: Subscription, on req: Request) async throws -> Response
    
    func verify(req: Request) async throws -> Response
    
}


public extension SubscriberRouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        try self.setup(routes: routes)
    }
    
    func setup(routes: RoutesBuilder, middlewares: [Middleware] = []) throws {
        let couldBeMiddlewaredRoute = routes.grouped(middlewares)
        couldBeMiddlewaredRoute.get("subscribe", use: subscribe)
        let routesGroup = routes.grouped(path)
        routesGroup.group("callback") { routeBuilder in
            routeBuilder.group(":id") { subBuilder in
                subBuilder.get(use: verify)
                subBuilder.post(use: handle)
            }
        }
    }
    
    func subscribe(req: Request) async throws -> Response {
        switch (
            Result { try req.query.decode(SubscribeRequest.self) }
        ) {
        case .success(let request):
            let mode = request.mode ?? .subscribe
            req.logger.info(
                """
                A user attempting to: \(mode)
                for topic: \(request.topic)
                """
            )
            switch mode {
            case .subscribe:
                return try await self.subscribe(request, on: req, then: self)
            case .unsubscribe:
                return try await self.unsubscribe(request, on: req, then: self)
            }
        case .failure(let reason):
            return try await ErrorResponse(
                code: .badRequest,
                message: reason.localizedDescription
            ).encodeResponse(status: .badRequest, for: req)
        }
    }
    
    func handle(req: Request) async throws -> Response {
        req.logger.info(
            """
            Incoming request: \(req.id)
            attempting to handle payload: \(req.body)
            """
        )
        switch try await req.validSubscription() {
        case .success(let subscription):
            req.logger.info(
                """
                Payload for validated subscription: \(subscription)
                from request: \(req.id)
                """
            )
            return try await self.payload(for: subscription, on: req)
        case .failure:
            req.logger.info(
                """
                Payload rejected from request: \(req.id)
                """
            )
            return Response(status: .notAcceptable)
        }
    }
    
    func verify(req: Request) async throws -> Response {
        switch (
            Result { try req.query.decode(SubscriptionVerificationRequest.self) }
        ) {
        case .success(let request):
            req.logger.info(
                """
                A hub attempting to: \(request.mode)
                verification for topic: \(request.topic)
                with challenge: \(request.challenge)
                via callback: \(req.url.path)
                """
            )
            guard let subscription = try await Subscriptions.first(
                topic: request.topic,
                callback: req.urlPath,
                on: req.db
            ) else {
                return Response(status: .notFound)
            }
            switch request.mode {
            case .subscribe:
                return try await self.verifySubscription(
                    subscription,
                    verification: request,
                    on: req
                )
            case .unsubscribe:
                return try await self.verifyUnsubscription(
                    subscription,
                    verification: request,
                    on: req
                )
            }
        case .failure(let reason):
            return try await ErrorResponse(
                code: .badRequest,
                message: reason.localizedDescription
            ).encodeResponse(status: .badRequest, for: req)
        }
    }
    
}


// MARK: - Utilities Extension

extension Request {
    
    func findRelatedSubscription() async throws -> SubscriptionModel? {
        return try await SubscriptionModel.query(on: self.db)
            .filter(\.$callback, .equal, self.urlPath)
            .first()
    }
    
    func validSubscription() async throws -> Result<Subscription, Error> {
        if let subscription = try await self.subscriptionFromHeaders() {
            return .success(subscription)
        }
        if let subscription = try await self.subscriptionFromContent() {
            return .success(subscription)
        }
        return .failure(HTTPResponseStatus.notAcceptable)
    }
    
    func subscriptionFromHeaders() async throws -> Subscription? {
        guard let subscription0 = try await self.findRelatedSubscription() else {
            return nil
        }
        guard let subscription1 = self.headers.extractWebSubLinks() else {
            return nil
        }
        if subscription0.topic == subscription1.topic && subscription0.hub == subscription1.hub {
            return subscription0
        }
        return nil
    }
    
    func subscriptionFromContent() async throws -> Subscription? {
        guard let subscription0 = try await self.findRelatedSubscription() else {
            return nil
        }
        guard let subscription1 = self.body.string?.extractWebSubLinks() else {
            return nil
        }
        if subscription0.topic == subscription1.topic && subscription0.hub == subscription1.hub {
            return subscription0
        }
        return nil
    }
    
    func generateCallbackURLString() -> String {
        return "\(Environment.get("WEBSUB_HOST") ?? "")\(self.url.path.dropSuffix("/subscribe"))/callback/\(UUID().uuidString)"
    }
    
    var urlPath: String {
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
