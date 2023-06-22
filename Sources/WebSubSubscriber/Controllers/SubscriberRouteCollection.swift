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

import Vapor


public protocol SubscriberRouteCollection:
        RouteCollection,
        PreparingToSubscribe,
        PreparingToUnsubscribe,
        Subscribing,
        Discovering,
        VerifyingToSubscribe,
        VerifyingToUnsubscribe,
        ReceivingPayload
    {
    
    var path: PathComponent { get }
    
    func setup(routes: RoutesBuilder, middlewares: [Middleware]) throws
    
    func subscribe(req: Request) async throws -> Response
    
    func verify(req: Request) async throws -> Response
    
    func receiving(req: Request) async throws -> Response
    
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
                subBuilder.post(use: receiving)
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
    
    func receiving(req: Request) async throws -> Response {
        req.logger.info(
            """
            Incoming request: \(req.id)
            attempting to handle payload: \(req.body)
            """
        )
        guard let subscription = try await Subscriptions.first(
            callback: req.urlPath,
            on: req.db
        ) else {
            return Response(status: .notFound)
        }
        return try await self.receiving(req, from: subscription)
    }
    
}
