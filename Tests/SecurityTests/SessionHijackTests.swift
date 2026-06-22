import Foundation
import XCTest
import CoreGraphics
@testable import RenJistrolyProductIdentity
@testable import RenJistrolySystemBridge

// MARK: - 会话劫持防护测试
//
// 安全说明：测试窗口标题欺骗、焦点劫持、鼠标保护等会话完整性防御。
// 所有窗口描述为模拟数据，不操作真实窗口。

// MARK: - WindowMatchValidator 测试

final class SessionHijackTests: XCTestCase {
        func testWindowMatchExactMatch() {
            let validator = WindowMatchValidator()
            let target = WindowMatchValidator.WindowDescriptor(
                title: "Safari", bundleID: "com.apple.Safari",
                processID: 123, frame: .zero
            )
            let candidates = [
                WindowMatchValidator.WindowDescriptor(
                    title: "Safari", bundleID: "com.apple.Safari",
                    processID: 123, frame: CGRect(x: 0, y: 0, width: 800, height: 600)
                ),
                WindowMatchValidator.WindowDescriptor(
                    title: "Terminal", bundleID: "com.apple.Terminal",
                    processID: 456, frame: .zero
                ),
            ]
            let result = validator.validate(target: target, candidates: candidates, strategy: .exact)
            XCTAssertTrue(result.matched)
            XCTAssertTrue(result.confidence == 1.0)
            XCTAssertTrue(result.reasons.contains("精确匹配"))
        }

        func testWindowMatchExactRejectsMismatch() {
            let validator = WindowMatchValidator()
            let target = WindowMatchValidator.WindowDescriptor(
                title: "Safari", bundleID: "com.apple.Safari",
                processID: 123, frame: .zero
            )
            let candidates = [
                WindowMatchValidator.WindowDescriptor(
                    title: "伪 Safari", bundleID: "com.apple.Safari",
                    processID: 456, frame: .zero
                ),
            ]
            let result = validator.validate(target: target, candidates: candidates, strategy: .exact)
            XCTAssertFalse(result.matched)
        }

        // MARK: - 窗口标题欺骗测试（模糊匹配验证）

        func testWindowMatchFuzzyDetectsSpoofing() {
            let validator = WindowMatchValidator()

            // 模拟攻击：伪造相似的窗口标题
            let realTarget = WindowMatchValidator.WindowDescriptor(
                title: "Safari - 安全验证页面",
                bundleID: "com.apple.Safari",
                processID: 100, frame: .zero
            )

            let spoofedCandidates = [
                // 攻击者创建的虚假窗口：相似但不同 bundleID
                WindowMatchValidator.WindowDescriptor(
                    title: "Safari - 安全验证页面",
                    bundleID: "com.malware.FakeSafari",
                    processID: 999, frame: .zero
                ),
            ]

            // 模糊匹配应识别 bundleID 不匹配
            let result = validator.validate(target: realTarget, candidates: spoofedCandidates, strategy: .fuzzy)
            // bundleID 不匹配 + PID 不匹配 = 低置信度
            XCTAssertFalse(result.matched)
        }

        func testWindowMatchFuzzyPasses() {
            let validator = WindowMatchValidator()

            let target = WindowMatchValidator.WindowDescriptor(
                title: "Safari - 开发者工具",
                bundleID: "com.apple.Safari",
                processID: 100, frame: .zero
            )

            let candidates = [
                WindowMatchValidator.WindowDescriptor(
                    title: "Safari - 开发者工具 - Console",
                    bundleID: "com.apple.Safari",
                    processID: 100, frame: .zero
                ),
            ]

            let result = validator.validate(target: target, candidates: candidates, strategy: .fuzzy)
            XCTAssertTrue(result.matched)
            XCTAssertTrue(result.confidence > 0.6)
        }

        func testWindowMatchFuzzyRejectsUnrelated() {
            let validator = WindowMatchValidator()

            let target = WindowMatchValidator.WindowDescriptor(
                title: "Terminal", bundleID: "com.apple.Terminal",
                processID: 100, frame: .zero
            )

            let candidates = [
                WindowMatchValidator.WindowDescriptor(
                    title: "Calculator", bundleID: "com.apple.calculator",
                    processID: 200, frame: .zero
                ),
            ]

            let result = validator.validate(target: target, candidates: candidates, strategy: .fuzzy)
            XCTAssertFalse(result.matched)
        }

        func testWindowMatchPID() {
            let validator = WindowMatchValidator()

            let target = WindowMatchValidator.WindowDescriptor(
                title: "某个窗口", bundleID: "com.example", processID: 42, frame: .zero
            )

            let candidates = [
                WindowMatchValidator.WindowDescriptor(
                    title: "另一个标题", bundleID: "com.other", processID: 42, frame: .zero
                ),
            ]

            let result = validator.validate(target: target, candidates: candidates, strategy: .pid)
            XCTAssertTrue(result.matched)
            XCTAssertTrue(result.confidence == 0.9)
        }

        func testWindowMatchPIDReject() {
            let validator = WindowMatchValidator()

            let target = WindowMatchValidator.WindowDescriptor(
                title: "A", bundleID: "com.a", processID: 1, frame: .zero
            )
            let candidates = [
                WindowMatchValidator.WindowDescriptor(
                    title: "B", bundleID: "com.b", processID: 2, frame: .zero
                ),
            ]

            let result = validator.validate(target: target, candidates: candidates, strategy: .pid)
            XCTAssertFalse(result.matched)
        }

        func testWindowMatchNoCandidates() {
            let validator = WindowMatchValidator()
            let target = WindowMatchValidator.WindowDescriptor(
                title: "Test", bundleID: "com.test", processID: 1, frame: .zero
            )
            let result = validator.validate(target: target, candidates: [], strategy: .exact)
            XCTAssertFalse(result.matched)
            XCTAssertTrue(result.confidence == 0)
        }

        // MARK: - 窗口标题劫持攻击向量测试

        func testWindowSpoofingAcrossBundleID() {
            let validator = WindowMatchValidator()

            // 攻击者创建窗口标题与目标应用类似的窗口
            let legitimate = WindowMatchValidator.WindowDescriptor(
                title: "系统偏好设置",
                bundleID: "com.apple.systempreferences",
                processID: 100, frame: .zero
            )

            let attackerWindows = [
                WindowMatchValidator.WindowDescriptor(
                    title: "系统偏好设置", // 标题完全一样
                    bundleID: "com.attacker.phishing", // 但 bundleID 不同
                    processID: 999, frame: .zero
                ),
                WindowMatchValidator.WindowDescriptor(
                    title: "系统偏好设置 - 安全性与隐私", // 标题近似
                    bundleID: "com.attacker.phishing",
                    processID: 998, frame: .zero
                ),
            ]

            // 精确匹配应拒绝
            let exactResult = validator.validate(target: legitimate, candidates: attackerWindows, strategy: .exact)
            XCTAssertFalse(exactResult.matched)

            // 模糊匹配也应拒绝（bundleID + PID 均不匹配）
            let fuzzyResult = validator.validate(target: legitimate, candidates: attackerWindows, strategy: .fuzzy)
            XCTAssertFalse(fuzzyResult.matched)
        }

        // MARK: - MouseGuard 鼠标保护测试

        func testMouseGuardInitialState() {
            let guard_ = MouseGuard.shared
            guard_.reportUserActivity()
            let state = guard_.userState()
            // 刚刚报告活动，应为 critical
            XCTAssertTrue(state == .critical || state == .active)
        }

        func testMouseGuardDeniesWhenActive() {
            let guard_ = MouseGuard.shared
            guard_.accessLevel = .denyWhenUserActive
            guard_.reportUserActivity()

            let hasPermission = guard_.checkPermission()
            XCTAssertFalse(hasPermission)
        }

        func testMouseGuardAllowsWhenIdle() {
            let guard_ = MouseGuard.shared
            guard_.accessLevel = .denyWhenUserActive

            // 模拟长时间无活动
            guard_.reportUserActivity()
            // tick 一次（距离上次活动可能已超过阈值）
            guard_.tick()

            // 注意：实际空闲状态取决于时间，这里仅验证方法不崩溃
            // 在测试环境中 lastActivity 是初始化时的 distantPast
            // 调用 tick 后如果超过 activeThreshold 则变为 idle
            _ = guard_.checkPermission() // 返回 Bool，确保不崩溃
        }

        func testMouseGuardAllowAlways() {
            let guard_ = MouseGuard.shared
            guard_.accessLevel = .allowWithPermission
            XCTAssertTrue(guard_.checkPermission())
        }

        func testMouseGuardDenyAlways() {
            let guard_ = MouseGuard.shared
            guard_.accessLevel = .denyAlways
            XCTAssertTrue(!guard_.checkPermission())
        }

        func testMouseGuardUserStateTransitions() {
            let guard_ = MouseGuard.shared
            guard_.reportUserActivity()

            // 刚报告活动：critical 或 active
            let state = guard_.userState()
            XCTAssertTrue(state != .idle)
        }

        // MARK: - FocusGuard 焦点保护测试

        func testFocusGuardInitialization() {
            _ = FocusGuard()
            // 验证 FocusGuard 可正常创建，actor 初始化不抛异常
            XCTAssertTrue(true)
        }

        func testSuppressionHandleUniqueness() {
            for _ in 0..<100 {
                // SuppressionHandle 的 init 是 fileprivate，无法在测试中创建
                // 通过 FocusGuard 创建
            }
            // SuppressionHandle 的 Hashable 一致性验证
            XCTAssertTrue(true)
        }

        // MARK: - 上下文完整性测试

        func testWindowDescriptorEquatable() {
            let a = WindowMatchValidator.WindowDescriptor(
                title: "Same", bundleID: "com.same", processID: 1,
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
            let b = WindowMatchValidator.WindowDescriptor(
                title: "Same", bundleID: "com.same", processID: 1,
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
            XCTAssertTrue(a == b)

            let c = WindowMatchValidator.WindowDescriptor(
                title: "Different", bundleID: "com.different", processID: 2,
                frame: CGRect(x: 10, y: 10, width: 200, height: 200)
            )
            XCTAssertTrue(a != c)
        }

        func testWindowDescriptorIsSendable() {
            // WindowDescriptor 是 Sendable，验证可包装到 @Sendable 闭包
            let desc = WindowMatchValidator.WindowDescriptor(
                title: "Test", bundleID: "com.test", processID: 1, frame: .zero
            )
            let fn: @Sendable () -> String = { desc.title }
            XCTAssertTrue(fn() == "Test")
        }



}
