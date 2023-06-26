//
//  VerifyRequestRaw.swift
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


public struct VerifyRequestRaw: Codable {
    
    public let mode: SubscriptionMode
    
    public let topic: String
    
    public let challenge: String
    
    public let leaseSeconds: Int?
    
    enum CodingKeys: String, CodingKey {
        case mode = "hub.mode"
        case topic = "hub.topic"
        case challenge = "hub.challenge"
        case leaseSeconds = "hub.lease_seconds"
    }
    
}


extension VerifyRequestRaw: Content { }


extension VerifyRequestRaw: RequestHandler {
    
    public typealias ResultType = VerifyRequestUseCases
    
    public func handle(on req: Request) async -> Result<VerifyRequestUseCases, ErrorResponse> {
        do {
            guard let subscription = try await Subscriptions.first(
                topic: self.topic,
                callback: req.urlPath,
                on: req.db
            ) else {
                throw HTTPResponseStatus.notFound
            }
            if self.isValid(for: subscription.state) {
                switch self.mode {
                case .subscribe:
                    return .success(
                        .verifySubscribe(
                            subscription: subscription,
                            leaseSeconds: self.leaseSeconds,
                            challenge: self.challenge
                        )
                    )
                case .unsubscribe:
                    return .success(
                        .verifyUnsubscribe(
                            subscription: subscription,
                            challenge: self.challenge
                        )
                    )
                }
            }
            subscription.lastUnsuccessfulVerificationAt = Date()
            try await subscription.save(on: req.db)
            throw HTTPResponseStatus.notFound
        } catch {
            return .failure(
                ErrorResponse(
                    code: .notFound,
                    message: "Not found"
                )
            )
        }
    }
    
}


extension VerifyRequestRaw {
    
    func isValid(for state: SubscriptionState) -> Bool {
        return (self.mode == .subscribe && state == .pendingSubscription) ||
        (self.mode == .unsubscribe && state == .pendingUnsubscription)
    }
    
}
