//
//  SubscriptionModel.swift
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


public final class SubscriptionModel: Subscription, Model, Content {
    
    public static let schema = "subscriptions"
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: "topic")
    public var topic: String
    
    @Field(key: "hub")
    public var hub: String
    
    @Field(key: "callback")
    public var callback: String
    
    @Field(key: "state")
    public var state: Subscription.State
    
    @Field(key: "lease_seconds")
    public var leaseSeconds: Int?
    
    @Field(key: "expired_at")
    public var expiredAt: Date?
    
    @Field(key: "last_successful_verification_at")
    public var lastSuccessfulVerificationAt: Date?
    
    @Field(key: "last_unsuccessful_verification_at")
    public var lastUnsuccessfulVerificationAt: Date?
    
    @Field(key: "last_received_content_at")
    public var lastReceivedContentAt: Date?
    
    public init() {}
    
    public init(id: UUID? = nil,
                topic: String,
                hub: String,
                callback: String,
                state: Subscription.State,
                leaseSeconds: Int? = nil,
                expiredAt: Date? = nil,
                lastSuccessfulVerificationAt: Date? = nil,
                lastUnsuccessfulVerificationAt: Date? = nil,
                lastReceivedContentAt: Date? = nil
    ) {
        self.id = id
        self.topic = topic
        self.hub = hub
        self.callback = callback
        self.state = state
        self.leaseSeconds = leaseSeconds
        self.expiredAt = expiredAt
        self.lastSuccessfulVerificationAt = lastSuccessfulVerificationAt
        self.lastUnsuccessfulVerificationAt = lastUnsuccessfulVerificationAt
        self.lastReceivedContentAt = lastReceivedContentAt
    }
    
}


public var Subscriptions: SubscriptionModels {
    return .init()
}


public final class SubscriptionModels {
    
    public init() { }
    
    public func create(
        topic: String,
        hub: String,
        callback: String,
        state: Subscription.State,
        leaseSeconds: Int?,
        on db: Database
    ) async throws -> SubscriptionModel {
        let subscription = SubscriptionModel(
            topic: topic,
            hub: hub,
            callback: callback,
            state: state,
            leaseSeconds: leaseSeconds
        )
        try await subscription.save(on: db)
        return subscription
    }
    
    public func first(
        topic: String? = nil,
        hub: String? = nil,
        callback: String? = nil,
        on db: Database
    ) async throws -> SubscriptionModel? {
        let query = SubscriptionModel.query(on: db)
        if let findTopic = topic {
            query.filter(\.$topic, .equal, findTopic)
        }
        if let findHub = hub {
            query.filter(\.$hub, .equal, findHub)
        }
        if let findCallback = callback {
            query.filter(\.$callback, .equal, findCallback)
        }
        return try await query.first()
    }
    
}
