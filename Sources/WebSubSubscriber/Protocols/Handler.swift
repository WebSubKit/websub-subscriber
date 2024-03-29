//
//  Handler.swift
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


public protocol Handler {
    
    associatedtype ResultType
    
}


// MARK: - Request Handler

public protocol RequestHandler: Handler {
    
    func handle(on req: Request) async -> Result<ResultType, ErrorResponse>
    
    func handle(on req: Request, then: @escaping(_ req: Request, _ handled: ResultType) async throws -> Response) async throws -> Response
    
}


extension RequestHandler {
    
    public func handle(on req: Request, then: @escaping(_ req: Request, _ handled: ResultType) async throws -> Response) async throws -> Response {
        switch await self.handle(on: req) {
        case .success(let handled):
            return try await then(req, handled)
        case .failure(let reason):
            return try await reason.encodeResponse(status: reason.code, for: req)
        }
    }
    
}


// MARK: - Command Handler

public protocol CommandHandler: Handler {
    
    func handle(on ctx: CommandContext) async -> Result<ResultType, ErrorResponse>
    
    func handle(on ctx: CommandContext, then: @escaping(_ ctx: CommandContext, _ handled: ResultType) async throws -> Void) async throws
    
}


extension CommandHandler {
    
    public func handle(on ctx: CommandContext, then: @escaping(_ ctx: CommandContext, _ handled: ResultType) async throws -> Void) async throws {
        switch await self.handle(on: ctx) {
        case .success(let handled):
            return try await then(ctx, handled)
        case .failure(let reason):
            throw reason
        }
    }
    
}


// MARK: - Application Handler

public protocol ApplicationHandler: Handler {

    func handle(on app: Application) async -> Result<ResultType, ErrorResponse>

    func handle(on app: Application, then: @escaping(_ app: Application, _ handled: ResultType) async throws -> Void) async throws

}


extension ApplicationHandler {

    public func handle(on app: Application, then: @escaping(_ app: Application, _ handled: ResultType) async throws -> Void) async throws {
        switch await self.handle(on: app) {
        case .success(let handled):
            return try await then(app, handled)
        case .failure(let reason):
            throw reason
        }
    }

}
