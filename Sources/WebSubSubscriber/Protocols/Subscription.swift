//
//  Subscription.swift
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

import Foundation


// MARK: - Subscription

public protocol Subscription {
    
    typealias State = SubscriptionState
    
    typealias Verification = SubscriptionVerification
    
    var topic: String { get }
    
    var hub: String { get }
    
    var callback: String { get }
    
    var state: Subscription.State { get }
    
    var leaseSeconds: Int? { get }
    
    var expiredAt: Date? { get }
    
    var lastSuccessfulVerificationAt: Date? { get }
    
    var lastUnsuccessfulVerificationAt: Date? { get }
    
    var lastReceivedContentAt: Date? { get }
    
}


// MARK: - Subscription State

public enum SubscriptionState: String {
    
    case unverified
    
    case verified
    
    case pendingSubscription
    
    case pendingUnsubscription
    
    case unsubscribed
    
}


extension SubscriptionState: Codable { }


// MARK: - Subscription Verification

public protocol SubscriptionVerification {
    
    typealias Mode = SubscriptionVerificationMode
    
    var mode: Mode { get }
    
    var topic: String { get }
    
    var challenge: String { get }
    
    var leaseSeconds: Int? { get }
    
}


public enum SubscriptionVerificationMode: String {
    
    case subscribe
    
    case unsubscribe
    
}


extension SubscriptionVerificationMode: Codable { }
