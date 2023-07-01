//
//  Subscribe.swift
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


public struct Subscribe: AsyncCommand {
    
    public struct Signature: CommandSignature {
        
        @Argument(name: "topic")
        var topic: String
        
        @Option(name: "hub", short: "h")
        var hub: String?
        
        @Option(name: "lease-seconds", short: "l")
        var leaseSeconds: Int?
        
        public init() { }
        
    }
    
    public init() { }
    
    public var help: String = "Subscribe a topic"
    
    public func run(using context: CommandContext, signature: Signature) async throws {
        try await signature.handle(on: context, then: self.subscribing)
    }
    
}


extension Subscribe.Signature: CommandHandler {
    
    public typealias ResultType = SubscribeRequestUseCases
    
    public func handle(on ctx: CommandContext) async -> Result<SubscribeRequestUseCases, ErrorResponse> {
        if let hub = self.hub {
            ctx.console.print(
                """
                Received subscribe request, with preferred hub
                topic        : \(self.topic)
                hub          : \(hub)
                leaseSeconds : \(String(describing: self.leaseSeconds))
                """
            )
            return .success(
                .subscribeWithPreferredHub(
                    topic: self.topic,
                    hub: hub,
                    leaseSeconds: self.leaseSeconds
                )
            )
        }
        ctx.console.print(
            """
            Received subscribe request, with no preferred hub
            topic        : \(self.topic)
            leaseSeconds : \(String(describing: self.leaseSeconds))
            """
        )
        return .success(
            .subscribeWithNoPreferredHub(
                topic: self.topic,
                leaseSeconds: self.leaseSeconds
            )
        )
    }
    
}


extension Subscribe: SubscribingFromCommand { }
