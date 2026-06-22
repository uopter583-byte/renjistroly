import Foundation

/// 自动回滚 — 自动修复失败时恢复到修改前的状态
public struct AutoRollback: Sendable {
    public struct Snapshot: Sendable {
        public let id: String
        public let timestamp: Date
        public let filePath: String
        public let content: Data
    }

    private var snapshots: [String: Snapshot] = [:]

    public init() {}

    /// 创建文件快照（修改前调用）
    public mutating func takeSnapshot(filePath: String) -> Snapshot? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        let id = UUID().uuidString
        let snapshot = Snapshot(id: id, timestamp: Date(), filePath: filePath, content: data)
        snapshots[filePath] = snapshot
        return snapshot
    }

    /// 回滚到快照版本
    public mutating func rollback(to snapshot: Snapshot) -> Bool {
        do {
            try snapshot.content.write(to: URL(fileURLWithPath: snapshot.filePath))
            snapshots.removeValue(forKey: snapshot.filePath)
            return true
        } catch {
            return false
        }
    }

    /// 清理快照
    public mutating func discard(filePath: String) {
        snapshots.removeValue(forKey: filePath)
    }
}
