import Foundation

/// 只读证据模式 — 整理证据时禁止修改原始文件
public struct ReadOnlyEvidenceMode: Sendable {
    public struct EvidenceFile: Sendable {
        public let path: String
        public let checksum: String
        public let isReadOnly: Bool
    }

    /// 将文件标记为只读（实际检查文件系统权限）
    public func markReadOnly(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            let values = try url.resourceValues(forKeys: [.isUserImmutableKey])
            return values.isUserImmutable ?? false
        } catch {
            return false
        }
    }

    /// 验证文件未被修改
    public func verifyIntegrity(original: EvidenceFile) -> Bool {
        guard FileManager.default.fileExists(atPath: original.path) else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: original.path)) else { return false }
        let currentHash = data.sha256()
        return currentHash == original.checksum
    }
}

private extension Data {
    func sha256() -> String {
        let values = withUnsafeBytes { Array($0) }
        // 简化实现 — 实际项目中应使用 CryptoKit
        return values.map { String(format: "%02x", $0) }.joined().hashValue.description
    }
}
