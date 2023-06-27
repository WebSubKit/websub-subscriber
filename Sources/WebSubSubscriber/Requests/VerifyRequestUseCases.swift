//
//  VerifyRequestUseCases.swift
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


public enum VerifyRequestUseCases {
    
    case verifySubscribe(subscription: SubscriptionModel, leaseSeconds: Int?, challenge: String)
    
    case verifyUnsubscribe(subscription: SubscriptionModel, challenge: String)
    
}


extension VerifyRequestUseCases: RequestHandler {
    
    public typealias ResultType = String
    
    public func handle(on req: Vapor.Request) async -> Result<String, ErrorResponse> {
        do {
            switch self {
            case .verifySubscribe(let subscription, let leaseSeconds, let challenge):
                try await subscription.verify(.subscribed, on: req.db)
                if let unwrapLeaseSeconds = leaseSeconds {
                    try await subscription.updateLeaseSeconds(unwrapLeaseSeconds, on: req.db)
                }
                return .success(challenge)
            case .verifyUnsubscribe(let subscription, let challenge):
                try await subscription.verify(.unsubscribed, on: req.db)
                return .success(challenge)
            }
        } catch {
            req.logger.error(
                """
                Validation request failed because (probably) internal server error
                request.id   : \(req.id)
                callback     : \(req.urlPath)
                err. message : \(error.localizedDescription)
                """
            )
            return .failure(
                ErrorResponse(
                    code: .internalServerError,
                    message: error.localizedDescription
                )
            )
        }
    }
    
}
