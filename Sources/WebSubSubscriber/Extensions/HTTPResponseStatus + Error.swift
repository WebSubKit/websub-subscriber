//
//  HTTPResponseStatus + Error.swift
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


/// `HTTPResponseStatus` extension for `CodingKey`
/// `CodingKey` is a type used to convert back and forth between JSON keys and Swift properties.
/// By extending `HTTPResponseStatus` to conform to the `CodingKey` protocol, we can use it as a key in JSON encoding/decoding.
extension HTTPResponseStatus: CodingKey {
    
    /// This computed property returns the reasonPhrase of the HTTP response status as a String.
    public var stringValue: String {
        return self.reasonPhrase
    }
    
    /// This initializer creates a new `HTTPResponseStatus` from a string.
    /// It creates a custom response status with a code of 600 and a reason phrase equal to the given string.
    ///
    /// - Parameter stringValue: A reason phrase
    public init(stringValue: String) {
        self = .custom(code: 600, reasonPhrase: stringValue)
    }
    
    /// This computed property returns the HTTP response status code as an Int.
    /// If the status code is not an integer, it will return nil.
    public var intValue: Int? {
        return Int(self.code)
    }
    
    /// This initializer creates a new `HTTPResponseStatus` from an integer.
    /// It creates a new response status with a status code equal to the given integer.
    /// 
    /// - Parameter intValue: A status code representing `HTTPResponseStatus`
    public init(intValue: Int) {
        self = .init(statusCode: intValue)
    }
    
}


/// In this extension, `HTTPResponseStatus` is declared to conform to the `Error` protocol.
/// This allows a `HTTPResponseStatus` to be thrown as an error.
/// No further methods or properties are implemented in this extension.
extension HTTPResponseStatus: Error { }


extension HTTPResponseStatus {
    
    /// This computed property returns a new `Response` object with the current `HTTPResponseStatus`.
    public var asResponse: Response {
        return Response(status: self)
    }
    
}


extension Error {
    
    /// This computed property attempts to cast self to `HTTPResponseStatus`.
    /// If the cast is successful, it returns the `HTTPResponseStatus`.
    /// If it's not, it creates a custom `HTTPResponseStatus` with a status code of 600
    /// and a reason phrase equal to the localized description of self.
    ///
    /// This is useful when you want to translate a Swift error into an HTTP response.
    /// You can simply call `asHTTPResponseStatus` on any Error to get a corresponding `HTTPResponseStatus`.
    ///
    /// Please note, that status code 600 is not a standard HTTP code
    /// and used in this code as a generic error indication.
    var asHTTPResponseStatus: HTTPResponseStatus {
        if let httpResponseStatus = self as? HTTPResponseStatus {
            return httpResponseStatus
        }
        return .custom(code: 600, reasonPhrase: self.localizedDescription)
    }
    
}
