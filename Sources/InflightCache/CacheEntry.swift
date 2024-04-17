import Foundation

/// Represents an entire cache with a status for each entry.
public typealias Cache<Id: Hashable, Output> = CacheWrapper<Id, CacheEntry<Output>>

/// Represents a slice of the cache
public typealias CacheSlice<Id: Hashable, Output> = [Id: CacheEntry<Output>]

/// Represents a slice of the cache with all entries fetched.
public typealias CacheSliceOutput<Id: Hashable, Output> = [Id: Result<Output, Error>]

/// Represents the status of an entry in cache.
/// Either in progress (retrieving the output), already fetched (available) or the request failed.
public enum CacheEntry<Output> {
    case inProgress(Task<Output, Error>)
    case fetched(Output)
    case failed(Error)

    public var fetchedValue: Output? {
        if case .fetched(let value) = self {
            return value
        }
        return nil
    }

    public func getValue() async throws -> Output {
        switch self {
        case .fetched(let value):
            return value
        case .inProgress(task: let task):
            return try await task.value
        case .failed(let error):
            throw error
        }
    }

    public var isValid: Bool {
        switch self {
        case .inProgress, .fetched:
            return true
        case .failed:
            return false
        }
    }
}
