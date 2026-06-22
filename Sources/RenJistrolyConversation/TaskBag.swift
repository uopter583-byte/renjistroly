import Foundation

public actor TaskBag {
    private final class Storage {
        var tasks: [String: Task<Void, Never>] = [:]
        deinit {
            tasks.values.forEach { $0.cancel() }
        }
    }

    private let storage = Storage()

    public init() {}

    public subscript(key: String) -> Task<Void, Never>? {
        get { storage.tasks[key] }
        set {
            storage.tasks[key]?.cancel()
            storage.tasks[key] = newValue
        }
    }

    public func set(key: String, task: Task<Void, Never>?) {
        storage.tasks[key]?.cancel()
        storage.tasks[key] = task
    }
}
