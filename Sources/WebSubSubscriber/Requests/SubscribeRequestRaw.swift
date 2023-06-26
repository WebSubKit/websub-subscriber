//
//  SubscribeRequestRaw.swift
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


public struct SubscribeRequestRaw: Codable {
    
    typealias Mode = SubscriptionMode
    
    let topic: String
    
    let mode: SubscribeRequestRaw.Mode?
    
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


extension SubscribeRequestRaw: Content { }


extension SubscribeRequestRaw: RequestHandler {
    
    public typealias ResultType = SubscribeRequestUseCases
    
    public func handle(on req: Request) async -> Result<SubscribeRequestUseCases, ErrorResponse> {
        let mode = self.mode ?? .subscribe
        switch mode {
        case .subscribe:
            if let hub = self.hub {
                req.logger.info(
                    """
                    Received \(mode) request, with preferred hub
                    request.id   : \(req.id)
                    topic        : \(self.topic)
                    hub          : \(hub)
                    leaseSeconds : \(String(describing: self.leaseSeconds))
                    """
                )
                return .success(
                    .subscribeWithPreferredHub(
                        topic: self.topic,
                        hub: hub,
                        leaseSeconds: self.leaseSeconds,
                        req: req
                    )
                )
            }
            req.logger.info(
                """
                Received \(mode) request, with no preferred hub
                request.id   : \(req.id)
                topic        : \(self.topic)
                leaseSeconds : \(String(describing: self.leaseSeconds))
                """
            )
            return .success(
                .subscribeWithNoPreferredHub(
                    topic: self.topic,
                    leaseSeconds: self.leaseSeconds,
                    req: req
                )
            )
        case .unsubscribe:
            guard let callback = self.callback else {
                req.logger.error(
                    """
                    Received \(mode) request, with error: Callback should be present on unsubscribe mode
                    request.id   : \(req.id)
                    """
                )
                return .failure(
                    ErrorResponse(
                        code: .badRequest,
                        message: "Callback should be present on unsubscribe mode"
                    )
                )
            }
            req.logger.info(
                """
                Received \(mode) request
                request.id   : \(req.id)
                topic        : \(self.topic)
                callback     : \(callback)
                """
            )
            return .success(
                .unsubscribe(
                    topic: self.topic,
                    callback: callback,
                    req: req
                )
            )
        }
    }
    
}
