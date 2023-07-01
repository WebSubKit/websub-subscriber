//
//  Unsubscribe.swift
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


public struct Unsubscribe: AsyncCommand {
    
    public struct Signature: CommandSignature {
        
        @Argument(name: "callback")
        var callback: String
        
        @Argument(name: "topic")
        var topic: String
        
        public init() { }
        
    }
    
    public var help: String = "Unsubscribe a subscription"
    
    public func run(using context: CommandContext, signature: Signature) async throws {
        try await signature.handle(on: context, then: self.subscribing)
    }
    
}


extension Unsubscribe.Signature: CommandHandler {
    
    public typealias ResultType = SubscribeRequestUseCases
    
    public func handle(on ctx: CommandContext) async -> Result<SubscribeRequestUseCases, ErrorResponse> {
        ctx.console.print(
            """
            Received unsubscribe request
            topic        : \(self.topic)
            callback     : \(self.callback)
            """
        )
        return .success(
            .unsubscribe(
                topic: self.topic,
                callback: self.callback
            )
        )
    }
    
}


extension Unsubscribe: SubscribingFromCommand { }
