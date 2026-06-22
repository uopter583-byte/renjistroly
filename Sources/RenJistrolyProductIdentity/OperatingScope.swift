import Foundation

/// 操作范围定义 — 明确 RenJistroly 能在哪些上下文中操作
public enum OperatingScope: String, Sendable, Codable, CaseIterable {
    case repository
    case application
    case desktop
    case voice

    public var title: String {
        switch self {
        case .repository: "仓库"
        case .application: "应用"
        case .desktop: "桌面"
        case .voice: "语音"
        }
    }

    public var detail: String {
        switch self {
        case .repository: "Git 仓库：代码读写、PR、commit、分支管理"
        case .application: "应用：打开、切换、关闭 Mac 应用"
        case .desktop: "桌面：文件管理、系统设置、UI 元素操控"
        case .voice: "语音：语音识别与合成交互"
        }
    }
}

/// 操作范围配置 — 控制哪些 Scope 当前可用
public struct OperatingScopeConfig: Sendable {
    public var enabledScopes: Set<OperatingScope>
    public var defaultScope: OperatingScope
    public var autoDetectScope: Bool

    public init(
        enabledScopes: Set<OperatingScope> = Set(OperatingScope.allCases),
        defaultScope: OperatingScope = .desktop,
        autoDetectScope: Bool = true
    ) {
        self.enabledScopes = enabledScopes
        self.defaultScope = defaultScope
        self.autoDetectScope = autoDetectScope
    }

    public func isEnabled(_ scope: OperatingScope) -> Bool {
        enabledScopes.contains(scope)
    }

    public func merging(_ other: OperatingScopeConfig) -> OperatingScopeConfig {
        OperatingScopeConfig(
            enabledScopes: enabledScopes.union(other.enabledScopes),
            defaultScope: defaultScope,
            autoDetectScope: autoDetectScope || other.autoDetectScope
        )
    }
}
