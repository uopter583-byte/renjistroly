import Foundation

/// 测试矩阵规划 — 防止越修越烂
public struct TestMatrixPlanner {
    public struct TestCase: Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let scope: OperatingScope
        public let category: Category
        public let precondition: String
        public let steps: [String]
        public let expectedResult: String

        public init(
            id: UUID = UUID(),
            name: String,
            scope: OperatingScope,
            category: Category,
            precondition: String,
            steps: [String],
            expectedResult: String
        ) {
            self.id = id
            self.name = name
            self.scope = scope
            self.category = category
            self.precondition = precondition
            self.steps = steps
            self.expectedResult = expectedResult
        }
    }

    public enum Category: String, Sendable, Codable {
        case accuracy
        case stability
        case safety
        case recovery
        case edgeCase
        case performance

        public var title: String {
            switch self {
            case .accuracy: "操作精度"
            case .stability: "屏幕稳定"
            case .safety: "安全策略"
            case .recovery: "错误恢复"
            case .edgeCase: "边界情况"
            case .performance: "性能"
            }
        }
    }

    public struct Matrix: Sendable {
        public let scope: OperatingScope
        public let cases: [TestCase]

        public init(scope: OperatingScope, cases: [TestCase]) {
            self.scope = scope
            self.cases = cases
        }

        public func filtered(by category: Category) -> [TestCase] {
            cases.filter { $0.category == category }
        }

        public var summary: String {
            let cats = Set(cases.map(\.category))
            return "范围: \(scope.title), 测试数: \(cases.count), 覆盖类别: \(cats.count)"
        }
    }

    public static func defaultMatrix(for scope: OperatingScope) -> Matrix {
        let cases: [TestCase] = [
            TestCase(
                name: "打开应用并验证窗口出现",
                scope: scope, category: .accuracy,
                precondition: "应用未运行",
                steps: ["执行 openApplication", "等待 2 秒", "验证窗口存在"],
                expectedResult: "目标应用窗口出现在前台"
            ),
            TestCase(
                name: "连续 10 次重复操作稳定性",
                scope: scope, category: .stability,
                precondition: "桌面状态正常",
                steps: ["重复 10 次", "记录每次结果"],
                expectedResult: "成功率 > 90%"
            ),
            TestCase(
                name: "删除操作触发安全拦截",
                scope: scope, category: .safety,
                precondition: "只读模式启用",
                steps: ["执行 deleteFile", "检查策略决策"],
                expectedResult: "策略拒绝或要求确认"
            ),
            TestCase(
                name: "目标窗口消失后自动恢复",
                scope: scope, category: .recovery,
                precondition: "目标窗口存在",
                steps: ["关闭目标窗口", "尝试点击"],
                expectedResult: "自动重新发现或报告"
            ),
            TestCase(
                name: "OCR 识别极端情况",
                scope: scope, category: .edgeCase,
                precondition: "屏幕内容为纯空",
                steps: ["请求 OCR", "解析结果"],
                expectedResult: "不崩溃，返回空结果"
            ),
            TestCase(
                name: "完整操作链路延迟",
                scope: scope, category: .performance,
                precondition: "系统空闲",
                steps: ["执行观察-规划-执行-验证链路"],
                expectedResult: "单次链路 < 5 秒"
            ),
        ]
        return Matrix(scope: scope, cases: cases)
    }
}
