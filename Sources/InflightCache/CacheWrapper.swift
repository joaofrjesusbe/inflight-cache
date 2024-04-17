import Foundation

/// A simple wrapper cache around NSCache for swift that stores values in memory.
public final class CacheWrapper<Key, Value> where Key: Hashable {
    public final class WrapperKey: NSObject {
        public let key: Key

        public init(_ key: Key) {
            self.key = key
        }

        public override var hash: Int {
            key.hashValue
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? WrapperKey else { return false }
            return value.key == key
        }
    }

    public final class WrapperValue<T>: NSObject {
        public let value: T

        public init(_ _struct: T) {
            self.value = _struct
        }
    }

    public let nsCache = NSCache<WrapperKey, WrapperValue<Value>>()

    public init() {
    }
}

public extension CacheWrapper {
    
    func get(key: Key) -> Value? {
        return nsCache.object(forKey: WrapperKey(key))?.value
    }

    func set(key: Key, value: Value) {
        let entry = WrapperValue(value)
        return nsCache.setObject(entry, forKey: WrapperKey(key))
    }

    func remove(key: Key) {
        nsCache.removeObject(forKey: WrapperKey(key))
    }

    func clear() {
        nsCache.removeAllObjects()
    }

    subscript(key: Key) -> Value? {
        get { return get(key: key) }
        set {
            guard let value = newValue else {
                // If nil was assigned using our subscript,
                // then we remove any value for that key:
                remove(key: key)
                return
            }

            set(key: key, value: value)
        }
    }
}
