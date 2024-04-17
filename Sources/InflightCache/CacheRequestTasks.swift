import Foundation

/// Represents the work need to be done to satisfy all input requests.
///  - `sharedTask` is the task that will be executed to retrieve the missing inputs from cache.
///  - `inProgressEntries` are the entries that are currently being retrieved that depends on the network task.
///  - `cacheEntries` are the entries that are already fetched from cache.
public struct CacheRequestTasks<Input, Output> where Input: Identifiable {
    public enum CacheRequestError: Swift.Error {
        case inputWithoutOutput
    }

    public let sharedTask: Task<[Output], Error>?
    public let inProgressEntries: CacheSlice<Input.ID, Output>
    public let inCacheEntries: CacheSlice<Input.ID, Output>

    /// represents all entries that belongs to the input requests.
    public var requestedEntries: CacheSlice<Input.ID, Output> {
        inProgressEntries.merging(inCacheEntries) { (_, new) in new }
    }

    public static func getTasks(
        inputs: [Input],
        cache: Cache<Input.ID, Output>,
        outputToId: @escaping (Output) -> Input.ID,
        sharedRequest: @escaping (([Input]) async throws -> [Output])
    ) -> CacheRequestTasks {

        let cacheStatus = CacheRequestState.getStatus(
            inputs: inputs,
            cache: cache)

        return getTasks(
            cacheStatus: cacheStatus,
            outputToId: outputToId,
            sharedRequest: sharedRequest
        )
    }

    public static func getTasks(
        cacheStatus: CacheRequestState<Input, Output>,
        outputToId: @escaping (Output) -> Input.ID,
        sharedRequest: @escaping (([Input]) async throws -> [Output])
    ) -> CacheRequestTasks {

        // Fill missing entries from cache, and mark them as in progress
        let missedCache = cacheStatus.missedCache
        var pendingEntries = CacheSlice<Input.ID, Output>()

        var pendingSharedTask: Task<[Output], Error>?
        if !cacheStatus.missedCache.isEmpty {
            let sharedTask = Task { [missedCache, sharedRequest] in
                try await sharedRequest(missedCache)
            }

            pendingSharedTask = sharedTask

            for input in missedCache {
                let id = input.id
                let task: Task<Output, Error> = Task { [id, sharedTask] in
                    let outputs = try await sharedTask.value
                    guard let output = outputs.first(where: { outputToId($0) == id }) else {
                        throw CacheRequestError.inputWithoutOutput
                    }
                    return output
                }

                let cacheEntry = CacheEntry.inProgress(task)
                pendingEntries[id] = cacheEntry
            }
        }

        return CacheRequestTasks(
            sharedTask: pendingSharedTask,
            inProgressEntries: pendingEntries,
            inCacheEntries: cacheStatus.inCacheEntries
        )
    }

    /// Returns all the entry outputs with final result (with entry fetched or failed).
    /// If some of the requests are still in progress, it will wait for them to finish.
    ///  - Returns: An array of outputs
    public func executeWork() async -> CacheSliceOutput<Input.ID, Output> {

        // Force and wait for shared task to execute
        if let sharedTask = sharedTask {
            let _ = try? await sharedTask.value
        }

        // Await all from requests, both in progress and fetched
        var outputSlice = CacheSliceOutput<Input.ID, Output>()
        await requestedEntries.asyncForEach { (key, entry) in
            do {
                let value = try await entry.getValue()
                outputSlice[key] = .success(value)
            } catch {
                outputSlice[key] = .failure(error)
            }
        }
        return outputSlice
    }
}
