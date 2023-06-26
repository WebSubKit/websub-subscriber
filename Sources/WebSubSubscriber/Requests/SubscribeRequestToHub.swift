//
//  SubscribeRequestToHub.swift
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


public struct SubscribeRequestToHub {
    
    let hub: URI
    
    let content: SubscribeRequestToHubContent
    
}


extension SubscribeRequestToHub {
    
    public init(mode: SubscriptionMode, subscription: any Subscription & Model) throws {
        self.hub = URI(string: subscription.hub)
        self.content = SubscribeRequestToHubContent(
            callback: subscription.callback,
            topic: subscription.topic,
            verify: "sync",
            mode: mode,
            leaseSeconds: subscription.leaseSeconds
        )
    }
    
}


extension SubscribeRequestToHub: RequestHandler {
    
    public typealias ResultType = (URI, (inout ClientRequest) throws -> ())
    
    public func handle(on req: Request) async -> Result<(URI, (inout ClientRequest) throws -> ()), ErrorResponse> {
        return .success((self.hub, { clientRequest in
            try clientRequest.content.encode(self.content)
        }))
    }
    
}


public struct SubscribeRequestToHubContent: Codable {
    
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


extension SubscribeRequestToHubContent: Content {
    
    public static var defaultContentType: HTTPMediaType = .urlEncodedForm
    
}
