import Foundation

/// Represents a snapshot of the cache of a given request.
/// It contains the list of inputs that are not in the cache,
/// plus the list of cache entries that are fetched and in progress.
public struct CacheRequestState<Input, Output> where Input: Identifiable {
    public let missedCache: [Input]
    public let inCacheEntries: CacheSlice<Input.ID, Output>

    public static func getStatus(
        inputs: [Input],
        cache: Cache<Input.ID, Output>
    ) -> CacheRequestState<Input, Output> {

        var missedCache = [Input]()
        var inCacheEntries = CacheSlice<Input.ID, Output>()

        // Fill existing requests (in progress and fetched)
        // And get missing from cache
        for input in inputs {
            let id = input.id
            if let request = cache[id], request.isValid {
                inCacheEntries[id] = request
            } else {
                missedCache.append(input)
            }
        }

        return CacheRequestState(missedCache: missedCache, inCacheEntries: inCacheEntries)
    }
}
