import Foundation

/// MDM 确认 — 配置 MDM 前必须严格确认
public struct MDMConfirmer: Sendable {
    public enum DeviceScope: String, Sendable {
        case allDevices, department, specificDevices
    }

    public struct MDMProfile: Sendable {
        public let identifier: String
        public let displayName: String
        public let installType: String
        public let removalAllowed: Bool
    }

    /// 确认前检查清单
    public struct Checklist: Sendable {
        public let profileVerified: Bool
        public let scopeConfirmed: Bool
        public let rollbackPlan: Bool
        public let userNotified: Bool
    }

    /// 验证 MDM 配置是否完整
    public func validate(profile: MDMProfile, checklist: Checklist) -> String? {
        var issues: [String] = []
        if !checklist.profileVerified { issues.append("MDM 配置文件未验证完整性") }
        if !checklist.scopeConfirmed { issues.append("部署范围未确认") }
        if !checklist.rollbackPlan { issues.append("无回滚计划") }
        if !checklist.userNotified { issues.append("用户未收到通知") }
        return issues.isEmpty ? nil : issues.joined(separator: "；")
    }

    /// 生成确认提示
    public func confirmationPrompt(profile: MDMProfile, scope: DeviceScope) -> String {
        """
        ⚠️ MDM 配置确认
        描述文件：\(profile.displayName) (\(profile.identifier))
        安装类型：\(profile.installType)
        部署范围：\(scope.rawValue)
        允许移除：\(profile.removalAllowed ? "是" : "否")

        请确认以下事项：
        1. MDM 配置文件已验证完整性
        2. 部署范围正确
        3. 已制定回滚计划
        4. 已通知受影响的用户
        """
    }
}
