import Foundation

/// 日志处理隔离 — 确保日志分析不泄露到本机之外
public struct LogProcessingIsolator: Sendable {
    public enum IsolationLevel: String, Sendable {
        case memoryOnly, localFile, networkAllowed
    }

    /// 当前隔离策略
    public let level: IsolationLevel

    public init(level: IsolationLevel = .memoryOnly) {
        self.level = level
    }

    /// 检查是否允许访问网络
    public func allowsNetwork() -> Bool {
        level == .networkAllowed
    }

    /// 检查是否允许持久化到磁盘
    public func allowsPersistence() -> Bool {
        level != .memoryOnly
    }

    /// 生成隔离说明
    public var description: String {
        switch level {
        case .memoryOnly: return "日志仅驻留内存，关闭会话后自动清除"
        case .localFile: return "日志写入本地加密文件，不会通过网络发送"
        case .networkAllowed: return "日志处理允许网络访问（请确保传输加密）"
        }
    }
}
