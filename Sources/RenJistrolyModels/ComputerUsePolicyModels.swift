import Foundation

public enum ComputerUseConfirmationMode: String, Sendable, Codable {
    case noConfirmation
    case preApprovalWorks
    case alwaysConfirm
    case handOffRequired

    public var title: String {
        switch self {
        case .noConfirmation: "无需确认"
        case .preApprovalWorks: "预授权可执行"
        case .alwaysConfirm: "执行前确认"
        case .handOffRequired: "必须用户接管"
        }
    }
}

public struct ComputerUsePolicyRule: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var title: String
    public var mode: ComputerUseConfirmationMode
    public var detail: String

    public init(id: String, title: String, mode: ComputerUseConfirmationMode, detail: String) {
        self.id = id
        self.title = title
        self.mode = mode
        self.detail = detail
    }
}

public struct ComputerUsePolicyCatalog: Sendable {
    public static let rules: [ComputerUsePolicyRule] = [
        ComputerUsePolicyRule(id: "delete-data", title: "删除本地或云端数据", mode: .alwaysConfirm, detail: "删除文件、邮件、帖子、会议、日历等必须执行前确认。"),
        ComputerUsePolicyRule(id: "accounts-permissions", title: "账号和权限", mode: .alwaysConfirm, detail: "创建账号最终提交、保存密码、创建 API Key、改权限必须确认。"),
        ComputerUsePolicyRule(id: "captcha", title: "验证码", mode: .alwaysConfirm, detail: "不得自动绕过验证码，必须让用户确认或接管。"),
        ComputerUsePolicyRule(id: "install-software", title: "安装或运行新软件", mode: .alwaysConfirm, detail: "安装新软件、运行刚下载的软件、安装扩展必须确认。"),
        ComputerUsePolicyRule(id: "third-party-message", title: "对外发送或发布", mode: .alwaysConfirm, detail: "微信、邮件、表单、社交评论等最终发送前必须确认。"),
        ComputerUsePolicyRule(id: "financial", title: "金融交易", mode: .alwaysConfirm, detail: "付款、订阅、取消付款计划等必须确认。"),
        ComputerUsePolicyRule(id: "system-settings", title: "系统设置", mode: .alwaysConfirm, detail: "改 VPN、安全设置、系统密码等必须确认。"),
        ComputerUsePolicyRule(id: "file-management", title: "移动或重命名文件", mode: .preApprovalWorks, detail: "明确预授权后可执行，否则执行前确认。"),
        ComputerUsePolicyRule(id: "sensitive-data", title: "传输敏感数据", mode: .preApprovalWorks, detail: "必须明确数据内容和目的地。"),
        ComputerUsePolicyRule(id: "browser-safety", title: "绕过安全拦截", mode: .handOffRequired, detail: "HTTPS 安全警告、付费墙等必须用户接管。"),
        ComputerUsePolicyRule(id: "basic-ui", title: "基础 UI 操作", mode: .noConfirmation, detail: "打开/切换 App、滚动、复制、低风险输入、读屏可执行。")
    ]
}
