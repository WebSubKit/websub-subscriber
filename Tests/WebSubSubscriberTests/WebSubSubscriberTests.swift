//
//  WebSubSubscriberTests.swift
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

@testable
import FluentSQLiteDriver
import WebSubSubscriber
import XCTVapor

final class WebSubSubscriberTests: XCTestCase {
    
    func testDiscovery() async throws {
        
        let app = Application(.testing)
        defer {
            app.shutdown()
        }
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.migrations.add(CreateSubscriptionsTable())
        try await app.autoMigrate()
        
        let prefix: PathComponent = ""
        try app.register(collection: SubscriberController(prefix))
        
        for spec in 100...104 {
            let topic = "https://websub.rocks/blog/\(spec)/zLwQiWt98z8kOAu4RXZF"
            let testURI = "\(prefix)/subscribe?topic=\(topic)"
            try app.test(.GET, testURI, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let response = try! res.content.decode([String: String].self)
                XCTAssertEqual(response["hub.topic"], topic)
                XCTAssertContains(response["hub.callback"], "\(prefix)/callback")
                XCTAssertEqual(response["hub.verify"], "sync")
                XCTAssertEqual(response["hub.mode"], "subscribe")
            })
        }
        
    }
    
}
