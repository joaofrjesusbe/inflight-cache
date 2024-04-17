import Foundation

public actor InflightCache<Input, Output> where Input: Identifiable {
    public struct Config {
        var outputToId: (Output) -> Input.ID
        var sharedRequest: ([Input]) async throws -> [Output]
    }

    private let cache: Cache<Input.ID, Output>
    private let config: Config

    public init(config: Config) {
        self.init(config: config, initalCache: Cache())
    }

    public init(config: Config, initalCache: Cache<Input.ID, Output>) {
        self.config = config
        self.cache = initalCache
    }

    @discardableResult
    public func requestValues(
        inputs: [Input]
    ) async -> CacheSliceOutput<Input.ID, Output> {
        let tasks = CacheRequestTasks.getTasks(
            inputs: inputs,
            cache: cache,
            outputToId: config.outputToId,
            sharedRequest: config.sharedRequest
        )

        for (key, entry) in tasks.inProgressEntries {
            cache[key] = entry
        }

        let results = await tasks.executeWork()
        await storeInCache(results: results)
        return results
    }

    public func cacheState(
        for inputs: [Input]
    ) async -> CacheRequestState<Input, Output> {
        CacheRequestState.getStatus(
            inputs: inputs,
            cache: cache
        )
    }

    private func storeInCache(results: CacheSliceOutput<Input.ID, Output>) async {
        for (key, entry) in results {
            do {
                let value = try entry.get()
                cache[key] = .fetched(value)
            } catch {
                cache[key] = nil
            }
        }
    }
}
