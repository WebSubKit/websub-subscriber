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
    
    func testWebSubSubscriber() async throws {
        
        let app = Application(.testing)
        defer {
            app.shutdown()
        }
        guard let subscriberHost = Environment.get("APP_SUBSCRIBER_HOST") else {
            fatalError("Please set APP_SUBSCRIBER_HOST on Environment.")
        }
        app.subscriber.host(subscriberHost)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.migrations.add(CreateSubscriptionsTable())
        try await app.autoMigrate()
        
        let prefix: PathComponent = ""
        try app.register(collection: SubscriberController(prefix))
        
        for spec in 100...104 {
            let topic = "https://websub.rocks/blog/\(spec)/tgPTwvcIy1lAzlm9Zzv4"
            let testURI = "\(prefix)/subscribe?topic=\(topic)"
            try app.testable(method: .running(port: 8080)).test(.GET, testURI, afterResponse: { res in
                XCTAssertEqual(res.status, .accepted)
            })
        }
        
        for spec in 200...204 {
            let topic = "https://websub.rocks/blog/\(spec)/tWVj7Lxcb7AmnKNGIm4n"
            let testURI = "\(prefix)/subscribe?topic=\(topic)"
            try app.testable(method: .running(port: 8080)).test(.GET, testURI, afterResponse: { res in
                XCTAssertEqual(res.status, .accepted)
            })
        }
        
        for spec in [205] {
            let topic = "https://websub.rocks/blog/\(spec)/wWRm2tB2ohwBchD3bdWk"
            let testURI = "\(prefix)/subscribe?topic=\(topic)"
            try app.testable(method: .running(port: 8080)).test(.GET, testURI, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
            })
        }
        
        for spec in [300] {
            let topic = "https://websub.rocks/blog/\(spec)/Qhvty2iKNTldEQ7N7zj7"
            let testURI = "\(prefix)/subscribe?topic=\(topic)"
            try app.testable(method: .running(port: 8080)).test(.GET, testURI, afterResponse: { res in
                XCTAssertEqual(res.status, .accepted)
            })
        }
        
    }
    
}
