import Foundation

/// 高风险操作确认 — 修改防火墙等高危操作前要求二次确认
public struct HighRiskOperationConfirmer: Sendable {
    public enum RiskCategory: String, Sendable {
        case firewall, networkConfig, systemPermission, kernelExtension, userManagement
    }

    public struct ConfirmationRequest: Sendable {
        public let category: RiskCategory
        public let operation: String
        public let impact: String
        public let requiresApproval: Bool
    }

    /// 各风险类别的确认要求
    public static let categoryDefaults: [RiskCategory: Bool] = [
        .firewall: true,
        .networkConfig: true,
        .systemPermission: true,
        .kernelExtension: true,
        .userManagement: true,
    ]

    /// 创建确认请求
    public func request(for category: RiskCategory, operation: String, impact: String) -> ConfirmationRequest {
        ConfirmationRequest(
            category: category,
            operation: operation,
            impact: impact,
            requiresApproval: Self.categoryDefaults[category] ?? true
        )
    }

    /// 生成确认提示文本
    public func prompt(for request: ConfirmationRequest) -> String {
        """
        ⚠️ 高风险操作确认
        类别：\(request.category.rawValue)
        操作：\(request.operation)
        影响：\(request.impact)

        请确认是否执行此操作。高风险操作可能影响系统安全性。
        """
    }
}
