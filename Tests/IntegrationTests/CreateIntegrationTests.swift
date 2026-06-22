import XCTest
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyEnterprise
@testable import RenJistrolyCapability

// MARK: - 端到端集成测试
//
// 三个核心场景：
//  1. 看屏 → 读窗 → 点按钮 → 验证（基本交互循环）
//  2. 模式切换 → 高风险操作 → 拦截 → 确认 → 执行（安全管控）
//  3. 连续操作 → 上下文切换 → 恢复（任务连续性）
//
// 所有测试继承 IntegrationTestBase，使用 mock 模拟真实系统调用。
// 需要权限时调用 requireMinimalPermissions()。

// MARK: - 场景 1：基本交互循环

final class CreateBasicInteractionTests: IntegrationTestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try requireMinimalPermissions()
    }

    /// 场景 1：看屏 → 读窗 → 点按钮 → 验证
    ///
    /// 模拟以下流程：
    /// 1. 读取屏幕内容（OCR / AX 快照）
    /// 2. 解析出可交互窗口
    /// 3. 定位目标元素
    /// 4. 执行点击操作
    /// 5. 验证操作结果
    func testScenario1ScreenReadWindowClickAndVerify() throws {
        // ---- Step 1: 读取屏幕 ----
        let screenCapture = try createTempFile(name: "screen-capture-1.png", content: "mock-png-data".data(using: .utf8)!)
        XCTAssertTrue(FileManager.default.fileExists(atPath: screenCapture.path), "屏幕捕获文件应存在")

        // 模拟 OCR 结果
        let mockOCRResult = """
        [{"text": "保存", "rect": {"x": 100, "y": 200, "w": 80, "h": 30}},
         {"text": "取消", "rect": {"x": 200, "y": 200, "w": 80, "h": 30}},
         {"text": "文件名:", "rect": {"x": 50, "y": 100, "w": 100, "h": 20}}]
        """

        // ---- Step 2: 读窗 ----
        let mockWindows: [String: Any] = [
            "appName": "TextEdit",
            "windowTitle": "无标题 — 编辑",
            "elements": [
                ["role": "AXButton", "title": "保存", "enabled": true],
                ["role": "AXButton", "title": "取消", "enabled": true],
                ["role": "AXTextField", "title": "文件名", "enabled": true],
            ]
        ]
        mockRegistry.register("currentWindows", value: mockWindows)
        mockRegistry.register("ocrResult", value: mockOCRResult)

        // 验证窗口存在
        let windows: [String: Any] = try requireMock("currentWindows")
        let appName = windows["appName"] as? String ?? ""
        XCTAssertEqual(appName, "TextEdit", "窗口应属于 TextEdit")

        // ---- Step 3: 定位目标元素 ----
        let elements = windows["elements"] as? [[String: Any]] ?? []
        let saveButton = elements.first { ($0["title"] as? String) == "保存" }
        XCTAssertNotNil(saveButton, "应找到「保存」按钮")
        let isEnabled = saveButton?["enabled"] as? Bool ?? false
        XCTAssertTrue(isEnabled, "「保存」按钮应可用")

        // ---- Step 4: 执行点击 ----
        // 模拟 ActionEngine 记录
        let engine = ActionEngine()
        let clickAction = engine.create(
            type: "click",
            preview: "点击「保存」按钮",
            riskLevel: .medium
        )
        XCTAssertEqual(clickAction.status, .pending, "操作初始状态应为 pending")

        let approved = engine.approve(clickAction.id)
        XCTAssertTrue(approved, "操作应被批准")

        let started = engine.start(clickAction.id)
        XCTAssertTrue(started, "操作应开始执行")

        let completed = engine.complete(clickAction.id, result: "clicked saved")
        XCTAssertTrue(completed, "操作应完成")

        // ---- Step 5: 验证 ----
        let finalRecord = engine.getRecord(clickAction.id)
        XCTAssertNotNil(finalRecord, "操作记录应存在")
        XCTAssertEqual(finalRecord?.status, .completed, "操作最终状态应为 completed")
        XCTAssertEqual(finalRecord?.result, "clicked saved", "应记录操作结果")

        // 验证审计追踪
        let auditTrail = finalRecord?.auditTrail ?? []
        XCTAssertGreaterThanOrEqual(auditTrail.count, 1, "应有审计记录")
        XCTAssertTrue(auditTrail.contains(where: { $0.event == "completed" }),
                     "审计追踪应包含 completed 事件")
    }
}

// MARK: - 场景 2：安全管控流程

@MainActor
final class CreateSecurityFlowTests: IntegrationTestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    /// 场景 2：模式切换 → 高风险操作 → 拦截 → 确认 → 执行
    ///
    /// 模拟以下流程：
    /// 1. 切换为只读模式
    /// 2. 尝试执行写入操作 → 被拦截
    /// 3. 切换为可执行模式
    /// 4. 高风险操作触发确认 → 用户确认 → 执行
    /// 5. 验证审计日志完整
    func testScenario2ModeSwitchHighRiskInterceptConfirmExecute() throws {
        let engine = ActionEngine()

        // ---- Step 1: 只读模式 ----
        let modeManager = ModeManager()
        modeManager.activate(.readOnly)
        XCTAssertTrue(modeManager.isActive(.readOnly), "只读模式应激活")

        // ---- Step 2: 写入操作被拦截 ----
        let writeAction = engine.create(
            type: "file_write",
            preview: "写入配置文件",
            riskLevel: .high
        )

        // ModeManager 评估操作
        let evalInReadOnly = modeManager.evaluate(writeAction.type, riskLevel: writeAction.riskLevel)
        XCTAssertFalse(evalInReadOnly.allowed, "只读模式下写入操作应被阻止")
        if let blockedBy = evalInReadOnly.blockedBy {
            XCTAssertEqual(blockedBy, .readOnly, "应被只读模式阻止")
        }

        // ---- Step 3: 切换模式 ----
        modeManager.deactivate(.readOnly)
        modeManager.activate(.executable)
        XCTAssertFalse(modeManager.isActive(.readOnly), "只读模式应已关闭")
        XCTAssertTrue(modeManager.isActive(.executable), "可执行模式应激活")

        // ---- Step 4: 高风险操作触发确认 ----
        let deleteAction = engine.create(
            type: "file_delete",
            preview: "删除重要文件",
            riskLevel: .critical
        )

        // 高风险操作应需要确认
        let evalInExecutable = modeManager.evaluate(deleteAction.type, riskLevel: deleteAction.riskLevel)
        XCTAssertTrue(evalInExecutable.allowed, "可执行模式下操作应被允许")
        XCTAssertTrue(evalInExecutable.requiresConfirmation, "高风险操作应要求确认")

        // 用户确认 — 批准操作
        let approved = engine.approve(deleteAction.id)
        XCTAssertTrue(approved, "用户确认后操作应被批准")
        XCTAssertEqual(engine.getRecord(deleteAction.id)?.status, .approved)

        // 执行
        let started = engine.start(deleteAction.id)
        XCTAssertTrue(started)
        let completed = engine.complete(deleteAction.id, result: "deleted with confirmation")
        XCTAssertTrue(completed)
        XCTAssertEqual(engine.getRecord(deleteAction.id)?.status, .completed)

        // ---- Step 5: 审计日志 ----
        let record = engine.getRecord(deleteAction.id)
        let audit = record?.auditTrail ?? []
        XCTAssertTrue(audit.contains(where: { $0.event == "created" }),
                     "审计应包含 created 事件")
        XCTAssertTrue(audit.contains(where: { $0.event == "approved" }),
                     "审计应包含 approved 事件")
        XCTAssertTrue(audit.contains(where: { $0.event == "completed" }),
                     "审计应包含 completed 事件")
    }

    @MainActor
    func testScenario2HighRiskActionRejected() throws {
        let engine = ActionEngine()
        let modeManager = ModeManager()
        modeManager.activate(.highRisk)

        let action = engine.create(
            type: "delete_all",
            preview: "批量删除文件",
            riskLevel: .critical
        )

        // 高风险模式下关键操作可被拒绝
        let rejected = engine.reject(action.id, reason: "高风险模式下禁止批量删除")
        XCTAssertTrue(rejected, "操作应被成功拒绝")
        XCTAssertEqual(engine.getRecord(action.id)?.status, .rejected)
    }
}

// MARK: - 场景 3：任务连续性与上下文恢复

final class CreateContextContinuityTests: IntegrationTestBase {

    /// 场景 3：连续操作 → 上下文切换 → 恢复
    ///
    /// 模拟以下流程：
    /// 1. 执行连续操作序列（A → B → C）
    /// 2. 中间插入上下文切换（不同应用 / 窗口）
    /// 3. 恢复操作并验证上下文正确
    /// 4. 验证历史记录的完整性
    func testScenario3ContinuousOpsContextSwitchAndResume() throws {
        let engine = ActionEngine()

        // ---- Step 1: 连续操作序列 ----
        let op1 = engine.create(type: "open_app", preview: "打开 Safari", riskLevel: .low)
        let _ = engine.approve(op1.id)
        let _ = engine.start(op1.id)
        let _ = engine.complete(op1.id, result: "Safari opened")

        let op2 = engine.create(type: "navigate", preview: "导航到 example.com", riskLevel: .low)
        let _ = engine.approve(op2.id)
        let _ = engine.start(op2.id)
        let _ = engine.complete(op2.id, result: "Navigated to example.com")

        let op3 = engine.create(type: "click", preview: "点击搜索栏", riskLevel: .low)
        let _ = engine.approve(op3.id)
        let _ = engine.start(op3.id)
        let _ = engine.complete(op3.id, result: "Search bar focused")

        // ---- Step 2: 上下文切换 ----
        // 模拟切换到邮件应用
        let op4 = engine.create(type: "switch_app", preview: "切换到邮件", riskLevel: .low)
        let _ = engine.approve(op4.id)
        let _ = engine.start(op4.id)
        let _ = engine.complete(op4.id, result: "Switched to Mail")

        let op5 = engine.create(type: "click", preview: "点击写邮件", riskLevel: .low)
        let _ = engine.approve(op5.id)
        let _ = engine.start(op5.id)
        let _ = engine.complete(op5.id, result: "New mail composer opened")

        // ---- Step 3: 恢复操作 ----
        // 模拟切换回 Safari 并继续之前操作
        let op6 = engine.create(type: "switch_app", preview: "切换回 Safari", riskLevel: .low)
        let _ = engine.approve(op6.id)
        let _ = engine.start(op6.id)
        let _ = engine.complete(op6.id, result: "Switched back to Safari")

        let op7 = engine.create(type: "insert_text", preview: "输入搜索关键词", riskLevel: .low)
        let _ = engine.approve(op7.id)
        let _ = engine.start(op7.id)
        let _ = engine.complete(op7.id, result: "Type 'hello' in search bar")

        // ---- Step 4: 验证历史记录 ----
        let history = engine.getRecentHistory(limit: 10)
        XCTAssertGreaterThanOrEqual(history.count, 7, "应有至少 7 条历史记录")

        // 验证操作顺序
        let types = history.map(\.type)
        XCTAssertEqual(types[0], "open_app", "第一个操作应为打开应用")
        XCTAssertEqual(types[1], "navigate", "第二个操作应为导航")
        XCTAssertTrue(types.contains("switch_app"), "应包含应用切换操作")
        XCTAssertEqual(types.last, "insert_text", "最后一个操作应为输入文字")

        // 验证上下文切换正确恢复
        let switchBackOps = history.filter { $0.type == "switch_app" }
        XCTAssertEqual(switchBackOps.count, 2, "应有两次应用切换")

        // 验证没有操作失败
        let failedOps = history.filter { $0.status == .failed || $0.status == .cancelled }
        XCTAssertTrue(failedOps.isEmpty, "所有操作应成功完成")
    }

    /// 验证操作失败后的恢复流程
    func testScenario3RecoveryAfterFailure() throws {
        let engine = ActionEngine()

        // 正常操作
        let op1 = engine.create(type: "read", preview: "读取文件", riskLevel: .low)
        let _ = engine.approve(op1.id)
        let _ = engine.start(op1.id)
        let _ = engine.complete(op1.id, result: "File read")

        // 失败的操作
        let op2 = engine.create(type: "write", preview: "写入文件", riskLevel: .medium)
        let _ = engine.approve(op2.id)
        let _ = engine.start(op2.id)
        let failed = engine.fail(op2.id, reason: "磁盘空间不足")
        XCTAssertTrue(failed, "操作应被标记为失败")
        XCTAssertEqual(engine.getRecord(op2.id)?.status, .failed)

        // 恢复 — 清理后重试
        let op3 = engine.create(type: "cleanup", preview: "清理磁盘空间", riskLevel: .medium)
        let _ = engine.approve(op3.id)
        let _ = engine.start(op3.id)
        let _ = engine.complete(op3.id, result: "Cleaned 500MB")

        let op4 = engine.create(type: "write", preview: "重新写入文件", riskLevel: .medium)
        let _ = engine.approve(op4.id)
        let _ = engine.start(op4.id)
        let _ = engine.complete(op4.id, result: "File written successfully")

        // 验证历史记录
        let history = engine.getRecentHistory(limit: 10)
        let failedOps = history.filter { $0.status == .failed }
        XCTAssertEqual(failedOps.count, 1, "应有一个失败的操作")
        XCTAssertEqual(failedOps.first?.failureReason, "磁盘空间不足",
                      "应记录失败原因")

        let successOps = history.filter { $0.status == .completed }
        XCTAssertEqual(successOps.count, 3, "应有 3 个成功操作（排除故障的和两次重试）")

        // 验证回退信息
        let failedRecord = history.first { $0.status == .failed }
        XCTAssertNotNil(failedRecord, "失败记录应存在")
    }
}
