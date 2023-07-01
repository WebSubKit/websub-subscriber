//
//  SubscribingFromCommand.swift
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


public protocol SubscribingFromCommand {
    
    func subscribing(from context: CommandContext, with useCase: SubscribeRequestUseCases) async throws
    
}


extension SubscribingFromCommand {
    
    public func subscribing(from context: CommandContext, with useCase: SubscribeRequestUseCases) async throws {
        try await useCase.handle(on: context, then: self.subscribing)
    }
    
    func subscribing(from context: CommandContext, for subscription: (mode: SubscriptionMode, item: SubscriptionModel)) async throws {
        try await SubscribeRequestToHub(mode: subscription.mode, subscription: subscription.item).handle(on: context, then: self.subscribing)
    }
    
    func subscribing(from context: CommandContext, then: (hub: URI, createClientRequest: (inout ClientRequest) throws -> ())) async throws {
        let response = try await context.application.client.post(then.hub, beforeSend: then.createClientRequest)
        context.application.logger.debug(
            """
            Response status : \(response.status)
            Response body :
            \(response.bodyString ?? "No content body")
            """
        )
    }
    
}
