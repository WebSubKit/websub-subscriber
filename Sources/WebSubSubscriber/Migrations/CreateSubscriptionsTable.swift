//
//  CreateSubscriptionsTable.swift
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


public struct CreateSubscriptionsTable: AsyncMigration {
    
    public func prepare(on database: Database) async throws {
        try await database.schema("subscriptions")
            .id()
            .field("topic", .string, .required)
            .field("hub", .string, .required)
            .field("callback", .string, .required)
            .field("state", .string, .required)
            .field("lease_seconds", .int)
            .field("expired_at", .datetime)
            .field("last_successful_verification_at", .datetime)
            .field("last_unsuccessful_verification_at", .datetime)
            .field("last_received_content_at", .datetime)
            .unique(on: "callback")
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("subscriptions").delete()
    }
    
    public init() { }
    
}
