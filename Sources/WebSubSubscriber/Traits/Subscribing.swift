//
//  Subscribing.swift
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


public protocol Subscribing {
    
    func subscribing(_ subscription: Subscription, mode: Subscription.Verification.Mode, via hub: URI, on req: Request) async throws -> Response
    
}


public extension Subscribing {
    
    func subscribing(_ subscription: Subscription, mode: Subscription.Verification.Mode, via hub: URI, on req: Request) async throws -> Response {
        req.logger.info(
            """
            Attempting to \(mode) topic: \(subscription.topic)
            via hub: \(subscription.hub)
            """
        )
        let subscribe = try await req.client.post(hub) { subscribeRequest in
            return try subscribeRequest.content.encode(
                SubscribeRequestToHub(
                    callback: subscription.callback,
                    topic: subscription.topic,
                    verify: "sync",
                    mode: mode,
                    leaseSeconds: subscription.leaseSeconds
                )
            )
        }
        req.logger.info(
            """
            Hub responded to \(mode) request: \(subscribe)
            """
        )
        if subscribe.status != .accepted {
            if let subscribeBody = subscribe.body {
                return Response(status: subscribe.status, body: .init(buffer: subscribeBody))
            }
            return Response(status: subscribe.status)
        }
        return Response(status: .ok)
    }
    
}


fileprivate struct SubscribeRequestToHub: Codable {
    
    typealias Mode = SubscriptionMode
    
    let callback: String
    
    let topic: String
    
    let verify: String
    
    let mode: Mode
    
    let leaseSeconds: Int?
    
    public enum CodingKeys: String, CodingKey {
        case callback = "hub.callback"
        case topic = "hub.topic"
        case verify = "hub.verify"
        case mode = "hub.mode"
        case leaseSeconds = "hub.lease_seconds"
    }
    
}


extension SubscribeRequestToHub: Content {
    
    static var defaultContentType: HTTPMediaType = .urlEncodedForm
    
}
