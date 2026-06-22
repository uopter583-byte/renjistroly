import Foundation

/// RenJistroly 产品定位：Mac Operating Agent — 不是通用助理，是 Mac 专用操作代理
public enum ProductIdentity {
    public static let productName = "RenJistroly"
    public static let tagline = "Your Mac Operating Agent"

    public static let description = "RenJistroly 是一个运行在 macOS 上的操作代理，"
        + "能直接操控屏幕、窗口、应用、文件和终端，"
        + "代替你完成需要在 Mac 上执行的复杂任务。"

    public static let coreCapabilities: [String] = [
        "屏幕感知 — 实时读取屏幕内容和 UI 元素",
        "窗口操控 — 打开、切换、关闭应用窗口",
        "文件操作 — 读写、移动、删除、搜索文件",
        "终端执行 — 在终端中运行命令和脚本",
        "键盘鼠标 — 模拟点击、输入、快捷键",
        "语音交互 — 语音输入输出双向对话",
    ]

    public static let outOfScope: [String] = [
        "不是 Android/iOS/Web 通用 Agent",
        "不操作远程服务器（SSH 除外）",
        "不是个人助手（不管理日历/邮件）",
        "不访问用户隐私数据",
    ]

    public static let version = "0.8.0"
}

extension ProductIdentity {
    public enum CapabilityLevel: Int, Sendable, Codable, Comparable {
        case observe = 0
        case readWrite = 1
        case automate = 2
        case autonomous = 3

        public static func < (lhs: CapabilityLevel, rhs: CapabilityLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var title: String {
            switch self {
            case .observe: "观察"
            case .readWrite: "读写"
            case .automate: "自动化"
            case .autonomous: "自主"
            }
        }
    }
}
