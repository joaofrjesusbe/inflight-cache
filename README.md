# InflightCache

A simple in-memory cache based on NSCache that takes in account in flight requests. It is useful when you want to avoid multiple requests for the same resource.
Supports concurrent request for the same resource and waits for the first request to complete.

## Usage

First create a configuration for the cache.
This as 2 properties:
- sharedRequest: a function that will be called when a request is not in the cache
- outputToId: a function that will be called to extract the id of the request value

Then create the cache with the configuration.

```swift
let config = InflightCache<Int, String>.Config(
    outputToId: { Int($0)! },
    sharedRequest: { $0.map(String.init) }
)
let cache = InflightCache(config: config)
```

Note: Input must conform to Identifiable protocol.
This way the cache can map Input to Output and vice versa.
On the example we can solve by adding:
```swift
extension Int: Identifiable {
    public var id: Int { self }
}
```

Now you can use the cache to get values and don't worry about multiple requests for the same resource.
```swift
let outputs = await sut.requestValues(inputs: inputs)
```
