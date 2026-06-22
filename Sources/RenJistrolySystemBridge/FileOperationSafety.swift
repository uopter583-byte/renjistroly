import Foundation

/// 文件操作安全 — 隔离文件操作防止误删
public struct FileOperationSafety: Sendable {
    public enum Operation: String, Sendable {
        case delete, move, overwrite
    }

    /// 受保护路径
    public let protectedPaths: [String]

    public init(protectedPaths: [String] = [
        "/System", "/Library", "/Applications",
        NSHomeDirectory() + "/Library",
    ]) {
        self.protectedPaths = protectedPaths
    }

    /// 检查操作目标是否受保护（含符号链接解析）
    public func isProtected(_ path: String) -> Bool {
        let resolved = resolveRealPath(path)
        return protectedPaths.contains { resolved.hasPrefix($0) || resolved == $0 }
    }

    /// 解析文件真实路径（跟随全部符号链接），防止通过符号链接绕过保护
    private func resolveRealPath(_ path: String) -> String {
        // resolvingSymlinksInPath() 在 macOS 10.12+ 上会解析路径中所有符号链接
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().standardized.path
    }

    /// 验证文件操作的安全性
    public func validate(operation: Operation, target: String) -> String? {
        guard isProtected(target) else { return nil }
        return "「\(target)」为受保护路径，不允许执行「\(operation.rawValue)」操作"
    }

    /// 将文件移至废纸篓而非永久删除
    public func safeDelete(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            return false
        }
    }
}
