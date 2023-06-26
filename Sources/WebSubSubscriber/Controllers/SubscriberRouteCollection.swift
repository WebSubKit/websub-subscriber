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
        Subscribing,
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
        return try await req.query.decode(SubscribeRequestRaw.self)
            .handle(on: req, then: { request in
                return try await request.handle(on: req, then: { mode, subscription in
                    return try await self.subscribing(
                        subscription,
                        mode: mode,
                        via: URI(string: subscription.hub),
                        on: req
                    )
                })
            })
    }
    
    func verify(req: Request) async throws -> Response {
        return try await VerifyRequest(from: req)
            .parse(
                on: req,
                then: { subscription, mode, challenge, leaseSeconds in
                    switch mode {
                    case .subscribe:
                        subscription.state = .subscribed
                        subscription.lastSuccessfulVerificationAt = Date()
                        if let withLeaseSeconds = leaseSeconds {
                            subscription.expiredAt = Calendar.current.date(byAdding: .second, value: withLeaseSeconds, to: Date())
                        }
                        try await subscription.save(on: req.db)
                        return Response(
                            status: .accepted,
                            body: .init(stringLiteral: challenge)
                        )
                    case .unsubscribe:
                        subscription.state = .unsubscribed
                        subscription.lastSuccessfulVerificationAt = Date()
                        try await subscription.save(on: req.db)
                        return Response(
                            status: .accepted,
                            body: .init(stringLiteral: challenge)
                        )
                    }
                }
            )
    }
    
    func receiving(req: Request) async throws -> Response {
        req.logger.info(
            """
            Incoming request: \(req.id)
            via callback: \(req.urlPath)
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
