//
//  SubscriberProvider.swift
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


extension Application {
    
    public struct Subscriber {

        final class Storage {

            var host: String

            init(host: String? = nil) {
                self.host = host ?? Environment.get("WEBSUB_HOST") ?? ""
            }

        }
        
        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        var storage: Storage {
            if self.application.storage[Key.self] == nil {
                self.initialize()
            }
            return self.application.storage[Key.self]!
        }

        func initialize() {
            self.application.storage[Key.self] = .init()
        }

        public var host: String {
            self.storage.host
        }

        public func host(_ host: String) {
            self.storage.host = host
        }
        
    }
    
    public var subscriber: Subscriber {
        return .init(application: self)
    }
    
}
