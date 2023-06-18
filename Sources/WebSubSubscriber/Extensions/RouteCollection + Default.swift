//
//  RouteCollection + Default.swift
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


public extension RouteCollection {
    
    /// A generic function named `handle` is added to the `RouteCollection`.
    /// This provides a structured way of handling requests and responses in a Vapor web application.
    /// It makes use of Swift's concurrency features (async/await) and generics,
    /// providing flexibility in processing different kinds of requests and tasks.
    ///
    /// - Parameters:
    ///   - req: An instance of `Request` representing the incoming HTTP request.
    ///   - task: An asynchronous closure which takes `Request` as an argument and returns a `Result` object. This closure performs some operation on the received request.
    ///   - success: A closure that takes a parameter of generic type `T` and returns a `Response`. This closure defines how to respond when the `task` succeeds.
    ///
    /// - Returns: A `Response` object.
    func handle<T>(_ req: Request, with task: (Request) async -> Result<T, Error>, success: (T) -> Response) async -> Response {
        switch await task(req) {
        case .success(let result):
            return success(result)
        case .failure(let reason):
            if let httpResponseStatus = reason as? HTTPResponseStatus {
                return Response(status: httpResponseStatus)
            }
            return self.defaultError(reason)
        }
    }
    
    /// The `defaultError` function is a helper function to handle errors that cannot be cast to `HTTPResponseStatus`.
    /// It generates and returns a new `Response` with the status set to `.internalServerError` (HTTP status code 500).
    ///
    /// - Parameter error: An error to be cast
    /// 
    /// - Returns: A Response from the given error
    func defaultError(_ error: Error) -> Response {
        return Response(status: .internalServerError)
    }
    
}

