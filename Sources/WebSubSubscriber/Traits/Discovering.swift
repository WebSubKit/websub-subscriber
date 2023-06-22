//
//  Discovering.swift
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


public protocol Discovering {
    
    func discovering(_ callback: String, from subscribeRequest: SubscribeRequest, on req: Request, state: Subscription.State) async throws -> Subscription
    
}


public extension Discovering {
    
    func discovering(_ callback: String, from subscribeRequest: SubscribeRequest, on req: Request, state: Subscription.State) async throws -> Subscription {
        if let requestedHub: String = subscribeRequest.hub {
            req.logger.info(
                """
                Preferred hub requested by the user found: \(requestedHub)
                """
            )
            return try await Subscriptions.create(
                topic: subscribeRequest.topic,
                hub: requestedHub,
                callback: callback,
                state: state,
                on: req.db
            )
        }
        guard let (topic, hub) = try await req.client.get(URI(string: subscribeRequest.topic)).extractWebSubLinks() else {
            throw HTTPResponseStatus.notFound
        }
        req.logger.info(
            """
            Preferred hub advertised by the topic found: \(hub)
            """
        )
        return try await Subscriptions.create(
            topic: topic,
            hub: hub,
            callback: callback,
            state: state,
            on: req.db
        )
    }
    
}
