//
//  VerifyRequest + Parser.swift
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


extension VerifyRequest: RequestParser {
    
    public typealias ParsedType = (SubscriptionModel, SubscriptionMode, String, Int?)
    
    public init(from req: Request) async {
        switch (
            Result { try req.query.decode(QueryVerifyRequest.self) }
        ) {
        case .success(let request):
            do {
                guard let subscription = try await Subscriptions.first(
                    topic: request.topic,
                    callback: req.urlPath,
                    on: req.db
                ) else {
                    self = .failure(
                        reason: ErrorResponse(
                            code: .notFound,
                            message: "Not found"
                        ),
                        req: req
                    )
                    return
                }
                if request.isValid(for: subscription.state) {
                    self = .verify(
                        mode: request.mode,
                        subscription: subscription,
                        challenge: request.challenge,
                        leaseSeconds: request.leaseSeconds,
                        req: req
                    )
                    return
                }
                subscription.lastUnsuccessfulVerificationAt = Date()
                try await subscription.save(on: req.db)
                self = .failure(
                    reason: ErrorResponse(
                        code: .notFound,
                        message: "Not found"
                    ),
                    req: req
                )
            } catch {
                self = .failure(
                    reason: ErrorResponse(
                        code: .internalServerError,
                        message: error.localizedDescription
                    ),
                    req: req
                )
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
    
    public func parse(on req: Request) async -> Result<(SubscriptionModel, SubscriptionMode, String, Int?), ErrorResponse> {
        switch self {
        case .verify(let mode, let subscription, let challenge, let leaseSeconds, _):
            return .success((subscription, mode, challenge, leaseSeconds))
        case .failure(let reason, _):
            return .failure(reason)
        }
    }
    
}


// MARK: - Query Verify Requets

fileprivate struct QueryVerifyRequest: Codable {
    
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

extension QueryVerifyRequest: Content { }


extension QueryVerifyRequest {
    
    func isValid(for state: SubscriptionState) -> Bool {
        return (self.mode == .subscribe && state == .pendingSubscription) ||
        (self.mode == .unsubscribe && state == .pendingUnsubscription)
    }
    
}
