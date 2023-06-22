//
//  MayHaveWebSubLinks.swift
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

import FeedKit
import Foundation
import SwiftSoup
import Vapor


protocol MayHaveWebSubLinks {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)?
    
}


extension String: MayHaveWebSubLinks {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        return self.extractTopicFromHTML() ?? self.extractTopicFromXML()
    }
    
    func extractTopicFromHTML() -> (topic: URI, hub: URI)? {
        let document = try? SwiftSoup.parse(self)
        return try? document?.head()?
            .select("link")
            .extractWebSubLinks()
    }
    
    func extractTopicFromXML() -> (topic: URI, hub: URI)? {
        return self.data(using: .utf8)?.extractWebSubLinks()
    }
    
}


extension Data: MayHaveWebSubLinks {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        switch FeedParser(data: self).parse() {
        case .success(let feed):
            return feed.atomFeed?.extractWebSubLinks() ?? feed.rssFeed?.extractWebSubLinks()
        case .failure:
            return nil
        }
    }
    
}


extension AtomFeed: MayHaveWebSubLinks {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        return self.links?.extractWebSubLinks()
    }
    
}


extension RSSFeed: MayHaveWebSubLinks {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        return self.atom?.links?.extractWebSubLinks()
    }
    
}

extension ClientResponse: MayHaveWebSubLinks {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        return self.headers.extractWebSubLinks() ?? self.bodyString?.extractWebSubLinks()
    }
    
    var bodyString: String? {
        if var body = self.body {
            return body.readString(length: body.readableBytes, encoding: .utf8)
        }
        return nil
    }
    
}


extension HTTPHeaders: MayHaveWebSubLinks {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        return self.links?.extractWebSubLinks()
    }
    
}


// MARK: Sequence extensionss

fileprivate extension Sequence where Element == SwiftSoup.Element {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        guard
            let topic = try? (
                self.first { element in (try? element.attr("rel") == "self") ?? false }?.attr("href")
            ),
            let hub = try? (
                self.first { element in (try? element.attr("rel") == "hub") ?? false }?.attr("href")
            )
        else {
            return nil
        }
        return (topic: URI(string: topic), hub: URI(string: hub))
    }
    
}

fileprivate extension Sequence where Element == AtomFeedLink {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        guard
            let topic = (
                self.first { link in link.attributes?.rel == "self" }?.attributes?.href
            ),
            let hub = (
                self.first { link in link.attributes?.rel == "hub" }?.attributes?.href
            )
        else {
            return nil
        }
        return (topic: URI(string: topic), hub: URI(string: hub))
    }
    
}


fileprivate extension Sequence where Element == HTTPHeaders.Link {
    
    func extractWebSubLinks() -> (topic: URI, hub: URI)? {
        guard
            let topic = (
                self.first { link in link.relation.rawValue == "self" }?.uri
            ),
            let hub = (
                self.first { link in link.relation.rawValue == "hub" }?.uri
            )
        else {
            return nil
        }
        return (topic: URI(string: topic), hub: URI(string: hub))
    }
    
}
