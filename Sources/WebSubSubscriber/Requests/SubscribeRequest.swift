//
//  SubscribeRequest.swift
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

import Fluent
import Vapor


public enum SubscribeRequest {
    
    case subscribeWithNoPreferredHub(topic: String, leaseSeconds: Int?, req: Request)
    
    case subscribeWithPreferredHub(topic: String, hub: String, leaseSeconds: Int?, req: Request)
    
    case unsubscribe(topic: String, callback: String, req: Request)
    
    case failure(reason: ErrorResponse, req: Request)
    
}


extension SubscribeRequest {
    
    public init(from req: Request) {
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
    
}


public struct QuerySubscribeRequest: Codable {
    
    typealias Mode = SubscriptionVerificationMode
    
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
