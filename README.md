# WebSubKit/WebSubSubscriber

A WebSub Subscriber implementation written in Swift for usage with 💧 [Vapor](https://github.com/vapor/vapor).

## 🗳️ Implemented Features

### Discovery

* [x] 100: HTTP header discovery - discovers the hub and self URLs from HTTP headers
* [x] 101: HTML tag discovery - discovers the hub and self URLs from the HTML `<link>` tags
* [x] 102: Atom feed discovery - discovers the hub and self URLs from the XML `<link>` tags
* [x] 103: RSS feed discovery - discovers the hub and self URLs from the XML `<atom:link>` tags
* [x] 104: Discovery priority - prioritizes the hub and self in HTTP headers over the links in the body

### Subscription

* [x] 1xx: Successfully creates a subscription
* [x] 200: Subscribing to a URL that reports a different rel=self
* [x] 201: Subscribing to a topic URL that sends an HTTP 302 temporary redirect
* [x] 202: Subscribing to a topic URL that sends an HTTP 301 permanent redirect
* [x] 203: Subscribing to a hub that sends a 302 temporary redirect
* [x] 204: Subscribing to a hub that sends a 301 permanent redirect
* [x] 205: Rejects a verification request with an invalid topic URL
* [ ] 1xx: Requests a subscription using a secret (optional)
  * Please select the signature method(s) that the subscriber recognizes. All methods listed below are currently acceptable for the hub to choose:
  * [ ] sha1
  * [ ] sha256
  * [ ] sha384
  * [ ] sha512
* [x] 1xx: Requests a subscription with a specific `lease_seconds` (optional, hub may ignore)
* [x] Callback URL is unique per subscription (should)
* [x] Callback URL is an unguessable URL (should)
* [ ] 1xx: Sends an unsubscription request

### Distribution

* [x] 300: Returns HTTP 2xx when the notification payload is delivered
* [ ] 1xx: Verifies a valid signature for authenticated distribution
* [ ] 301: Rejects a distribution request with an invalid signature
* [ ] 302: Rejects a distribution request with no signature when the subscription was made with a secret


## 📥 Installation

### Swift Package Manager

To integrate `WebSubSubscriber` into your project, specify it in your `Package.swift` file:

```swift
let package = Package(
    ...
    dependencies: [
        .Package(url: "https://github.com/WebSubKit/WebSubSubscriber.git", majorVersion: 0)
    ]
    ...
)
```


## ⛏️ Usage

### Migrate the subscriptions table

```swift 
    app.migrations.add(CreateSubscriptionsTable())
    ...
    try await app.autoMigrate()
```

### Create a new controller that conforms to `SubscriberRouteCollection`

```swift
struct SubscriberController: SubscriberRouteCollection {
    
    let path: PathComponent = ""
    
    func payload(req: Request) async throws -> Response {
        // handle the delivered payload here ...
        return Response(status: .noContent)
    }
    
}
```

### Register the controller to app

```swift
    try app.register(collection: SubscriberController())
```

### Created routes
```
GET  (path)/subscribe 
    -> discover topic and hub, called by user to create a new subscription to a topic via the advertised hub by the publisher 
GET  (path)/callback/(unique-subscription-id)
    -> verify the subscription, called by the hub to verify the requested subscription
POST (path)/callback/(unique-subscription-id)
    -> receive payload from the hub, called by the hub to deliver payload published by the publisher
```
