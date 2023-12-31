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
        SubscribingFromRequest,
        Verifying,
        Receiving
    {
    
    var path: PathComponent { get }
    
    func setup(routes: RoutesBuilder, middlewares: [Middleware]) throws
    
    func subscribe(req: Request) async throws -> Response
    
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
                subBuilder.post(use: receive)
            }
        }
    }
    
    func subscribe(req: Request) async throws -> Response {
        return try await self.subscribing(from: req)
    }
    
    func verify(req: Request) async throws -> Response {
        return try await self.verifying(from: req)
    }
    
    func receive(req: Request) async throws -> Response {
        return try await self.receiving(from: req)
    }
    
}
