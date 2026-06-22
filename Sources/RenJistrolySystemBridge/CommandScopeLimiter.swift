import Foundation

/// 命令范围限制 — 批量执行命令时限定可作用的目标范围，含并发控制
public struct CommandScopeLimiter: Sendable {
    public struct Scope: Sendable {
        public let allowedHosts: [String]
        public let allowedPaths: [String]
        public let maxConcurrent: Int

        public init(allowedHosts: [String] = ["localhost", "127.0.0.1", "::1"],
                    allowedPaths: [String] = ["/tmp", NSHomeDirectory() + "/Desktop", NSHomeDirectory() + "/Documents"],
                    maxConcurrent: Int = 5) {
            self.allowedHosts = allowedHosts
            self.allowedPaths = allowedPaths
            self.maxConcurrent = maxConcurrent
        }
    }

    public let scope: Scope

    /// 活跃命令计数器（actor 隔离，线程安全）
    private let activeCount = ConcurrentCounter()

    public init(scope: Scope = Scope(
        allowedHosts: ["localhost", "127.0.0.1", "::1"],
        allowedPaths: ["/tmp", NSHomeDirectory() + "/Desktop", NSHomeDirectory() + "/Documents"],
        maxConcurrent: 5
    )) {
        self.scope = scope
    }

    /// 验证目标主机是否在范围内
    public func allowsHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // IPv6 的 localhost 变体
        if normalized == "::1" || normalized == "0:0:0:0:0:0:0:1" {
            return scope.allowedHosts.contains { $0 == "::1" || $0 == "localhost" }
        }
        return scope.allowedHosts.contains(normalized)
    }

    /// 验证路径是否在范围内（带路径归一化和目录边界检查）
    public func allowsPath(_ path: String) -> Bool {
        let normalized = normalizePath(path)
        // 展开 ~ 符号
        let expanded = (normalized as NSString).expandingTildeInPath
        return scope.allowedPaths.contains { allowed in
            let allowedNorm = normalizePath(allowed)
            // 使用目录边界检查：确保路径在 allowed 目录下，而非仅仅是字符串前缀
            guard expanded.hasPrefix(allowedNorm) else { return false }
            // 如果 expanded 比 allowedNorm 长，下一个字符必须是路径分隔符
            if expanded.count > allowedNorm.count {
                let nextChar = expanded[expanded.index(expanded.startIndex, offsetBy: allowedNorm.count)]
                return nextChar == "/"
            }
            return true
        }
    }

    /// 路径归一化处理
    private func normalizePath(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        // 移除末尾的 /
        if standardized.count > 1 && standardized.hasSuffix("/") {
            return String(standardized.dropLast())
        }
        return standardized
    }

    /// 获取当前并发数
    public func currentConcurrency() -> Int {
        activeCount.value
    }

    /// 验证并发数是否在限制内，并尝试占位
    /// - Returns: true 表示可以执行（已占位），false 表示并发数达到上限
    public func tryAcquireConcurrencySlot() -> Bool {
        activeCount.incrementIfBelow(limit: scope.maxConcurrent)
    }

    /// 释放并发占位
    public func releaseConcurrencySlot() {
        activeCount.decrement()
    }

    /// 验证并占用并发数（同步检查，调用者在开始执行前调用）
    public func allowsConcurrency(_ count: Int) -> Bool {
        count <= scope.maxConcurrent
    }

    /// 完整检查：主机 + 路径 + 并发
    public func evaluate(host: String? = nil, path: String? = nil, subprocess: Bool = false) -> ScopeResult {
        if let h = host, !allowsHost(h) {
            return .denied(reason: "主机「\(h)」不在允许列表中")
        }

        if let p = path, !allowsPath(p) {
            return .denied(reason: "路径「\(p)」不在允许范围内")
        }

        if !tryAcquireConcurrencySlot() {
            return .denied(reason: "并发数已达上限（\(scope.maxConcurrent)），请等待其他任务完成")
        }

        return .allowed(isSubprocess: subprocess)
    }

    /// 释放之前 evaluate 占用的并发槽位
    public func completeExecution() {
        releaseConcurrencySlot()
    }

    /// 检查路径是否指向子进程可执行文件
    public func allowsSubprocess(atPath path: String) -> Bool {
        let allowedSubprocessPaths: [String] = [
            "/bin/", "/usr/bin/", "/sbin/", "/usr/sbin/",
            "/opt/homebrew/bin/", "/usr/local/bin/",
            NSHomeDirectory() + "/.local/bin",
        ]
        let expanded = (path as NSString).expandingTildeInPath
        let standardized = (expanded as NSString).standardizingPath
        return allowedSubprocessPaths.contains { standardized.hasPrefix($0) }
    }
}

/// 范围检查结果
public enum ScopeResult: Sendable {
    case allowed(isSubprocess: Bool)
    case denied(reason: String)

    public var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    public var denialReason: String? {
        if case .denied(let reason) = self { return reason }
        return nil
    }
}

/// 线程安全的并发计数器
final class ConcurrentCounter: Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var _value: Int = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func incrementIfBelow(limit: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _value < limit else { return false }
        _value += 1
        return true
    }

    func decrement() {
        lock.lock()
        defer { lock.unlock() }
        _value = max(0, _value - 1)
    }
}
