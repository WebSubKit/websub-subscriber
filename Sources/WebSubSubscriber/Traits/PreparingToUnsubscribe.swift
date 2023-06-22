//
//  PreparingToUnsubscribe.swift
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


public protocol PreparingToUnsubscribe {
    
    func unsubscribe(_ subscribeRequest: SubscribeRequest, on req: Request, then: Subscribing & Discovering) async throws -> Response
    
}


public extension PreparingToUnsubscribe {
    
    func unsubscribe(_ subscribeRequest: SubscribeRequest, on req: Request, then: Subscribing & Discovering) async throws -> Response {
        guard let callback = subscribeRequest.callback else {
            return try await ErrorResponse(
                code: .badRequest,
                message: "Callback URL is required when unsubscribing topic"
            ).encodeResponse(status: .badRequest, for: req)
        }
        if let fromDB = try await Subscriptions.first(callback: callback, on: req.db) {
            fromDB.state = .pendingUnsubscription
            try await fromDB.save(on: req.db)
            return try await then.subscribing(
                fromDB,
                mode: .unsubscribe,
                via: URI(string: fromDB.hub),
                on: req
            )
        }
        let subscription = try await then.discovering(
            callback,
            from: subscribeRequest,
            on: req,
            state: .pendingUnsubscription
        )
        return try await then.subscribing(
            subscription,
            mode: .unsubscribe,
            via: URI(string: subscription.hub),
            on: req
        )
    }
    
}
