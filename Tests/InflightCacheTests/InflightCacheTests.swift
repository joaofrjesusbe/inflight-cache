import XCTest
@testable import InflightCache

extension Int: Identifiable {
    public var id: Int { self }
}

struct Result: Identifiable, Comparable {
    var id: Int
    var string: String

    static func < (lhs: Result, rhs: Result) -> Bool {
        lhs.id < rhs.id
    }

    init(_ value: Int) {
        self.id = value
        // Simple transform an int to a string        
        self.string = String(value)
    }
}

final class InflightCacheTests: XCTestCase {
    var apiRequestCount: Int = 0
    var lastApiRequest: [Int] = []
    var config: InflightCache<Int, Result>.Config!

    private func simulateApiRequest(_ inputs: [Int]) async -> [Result] {
        try? await Task.sleep(nanoseconds: 1)
        apiRequestCount += 1
        lastApiRequest = inputs
        return inputs.map(Result.init)
    }

    override func setUp() async throws {
        apiRequestCount = 0
        lastApiRequest = []
        config = .init(
            outputToId: { $0.id },
            sharedRequest: simulateApiRequest
        )
    }

    func testEmptyRequestsCachedShouldFetch() async throws {
        // Given
        let inputs = [1, 2, 3]
        let sut = sut(withCached: [])

        // When
        await sut.requestValues(inputs: inputs)

        // Then
        await assert(
            sut: sut,
            inputs: inputs,
            apiRequestCount: 1,
            lastApiRequest: inputs
        )
    }

    func testAllRequestsCachedShouldNotFetch() async throws {
        // Given
        let inputs = [1, 2, 3]
        let sut = sut(withCached: inputs)

        // When
        await sut.requestValues(inputs: inputs)

        // Then
        await assert(
            sut: sut,
            inputs: inputs,
            apiRequestCount: 0,
            lastApiRequest: []
        )
    }

    func testPartialRequestsCachedShouldPartialFetch() async throws {
        // Given
        let inputs = [1, 2, 3]
        let sut = sut(withCached: [1, 2])

        // When
        await sut.requestValues(inputs: inputs)

        // Then
        await assert(
            sut: sut,
            inputs: inputs,
            apiRequestCount: 1,
            lastApiRequest: [3]
        )
    }

    func testMultipleRequestsShouldOnlyFetchOnce() async throws {
        // Given
        let inputs = [1, 2, 3]
        let sut = sut(withCached: [])

        // When
        await [inputs].concurrentForEach { _ in // run inputs.count times simultaneously
            await sut.requestValues(inputs: inputs)
        }

        // Then
        await assert(
            sut: sut,
            inputs: inputs,
            apiRequestCount: 1,
            lastApiRequest: inputs
        )
    }

    private func sut(withCached values: [Int]) -> InflightCache<Int, Result> {
        let cache = Cache<Int, Result>()
        for value in values {
            cache[value] = .fetched(.init(value))
        }
        return InflightCache(config: config, initalCache: cache)
    }

    private func assert(
        sut: InflightCache<Int, Result>,
        inputs: [Int],
        apiRequestCount: Int,
        lastApiRequest: [Int]
    ) async {
        let cacheState = await sut.cacheState(for: inputs)
        let cacheOutput = inputs.compactMap { cacheState.inCacheEntries[$0]?.fetchedValue }
        let expected = inputs.map(Result.init)

        // Then
        XCTAssertTrue(cacheState.missedCache.isEmpty)
        XCTAssertEqual(apiRequestCount, apiRequestCount)
        XCTAssertEqual(lastApiRequest, lastApiRequest)
        XCTAssertEqual(cacheOutput, expected)
    }
}
