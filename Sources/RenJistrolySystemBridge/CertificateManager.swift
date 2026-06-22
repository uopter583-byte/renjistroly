import Foundation

/// 证书管理安全 — 更新证书时防止误删旧证书
public struct CertificateManager: Sendable {
    public struct Certificate: Sendable {
        public let id: String
        public let commonName: String
        public let expiresAt: Date
        public let isBackedUp: Bool
    }

    /// 备份旧证书
    public func backup(certificate path: String, to backupDir: String) -> Bool {
        let fileManager = FileManager.default
        let backupURL = URL(fileURLWithPath: backupDir)
            .appendingPathComponent("cert_backup_\(Date().timeIntervalSince1970)")
            .appendingPathExtension("pem")

        do {
            try fileManager.createDirectory(atPath: backupDir, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: path) {
                try fileManager.copyItem(at: URL(fileURLWithPath: path), to: backupURL)
            }
            return true
        } catch {
            return false
        }
    }

    /// 更新证书时验证新旧证书一致性
    public func verifyUpdate(newPath: String, oldPath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: newPath) else { return false }
        guard FileManager.default.fileExists(atPath: oldPath) else { return true } // 新安装
        guard let newData = try? Data(contentsOf: URL(fileURLWithPath: newPath)) else { return false }
        guard let oldData = try? Data(contentsOf: URL(fileURLWithPath: oldPath)) else { return false }
        // 确保新证书与旧证书不同
        return newData != oldData && !newData.isEmpty
    }
}
