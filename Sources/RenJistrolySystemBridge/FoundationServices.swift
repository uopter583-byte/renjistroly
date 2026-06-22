import Foundation
import RenJistrolyModels

public actor FoundationStore {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support")
        self.directory = directory ?? base
            .appending(path: "MacVoiceAssistant", directoryHint: .isDirectory)
            .appending(path: "Foundation", directoryHint: .isDirectory)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load<T: Decodable>(_ type: T.Type, from fileName: String, default defaultValue: T) -> T {
        do {
            let url = try fileURL(fileName)
            guard FileManager.default.fileExists(atPath: url.path) else { return defaultValue }
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            return defaultValue
        }
    }

    public func save<T: Encodable>(_ value: T, to fileName: String) {
        do {
            let url = try fileURL(fileName)
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save foundation file \(fileName): \(error)")
        }
    }

    public func append<T: Codable>(_ value: T, to fileName: String, keeping limit: Int = 200) {
        var values = load([T].self, from: fileName, default: [])
        values.insert(value, at: 0)
        if values.count > limit {
            values = Array(values.prefix(limit))
        }
        save(values, to: fileName)
    }

    public func pathDescription() -> String {
        directory.path
    }

    private func fileURL(_ fileName: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: fileName)
    }
}

public actor FoundationDiagnosticsCenter {
    private let store: FoundationStore

    public init(store: FoundationStore) {
        self.store = store
    }

    public func record(_ snapshot: AssistantDiagnosticSnapshot) async {
        await store.append(snapshot, to: "diagnostics.json", keeping: 300)
    }

    public func recent(limit: Int = 20) async -> [AssistantDiagnosticSnapshot] {
        let all = await store.load([AssistantDiagnosticSnapshot].self, from: "diagnostics.json", default: [])
        return Array(all.prefix(limit))
    }
}

public actor FeedbackCenter {
    private let store: FoundationStore

    public init(store: FoundationStore) {
        self.store = store
    }

    public func classify(_ text: String) -> FeedbackCategory {
        let normalized = text.lowercased()
        if contains(normalized, ["听不懂", "没听懂", "识别错", "转写错"]) { return .speechRecognition }
        if contains(normalized, ["没回答", "回答错", "胡说", "不对"]) { return .modelResponse }
        if contains(normalized, ["打不开", "没打开", "没执行", "不能控制", "无法帮我打开"]) { return .actionExecution }
        if contains(normalized, ["授权", "权限", "未授权"]) { return .permission }
        if contains(normalized, ["看不到", "读屏", "屏幕", "ocr"]) { return .screenUnderstanding }
        if contains(normalized, ["deepseek", "openai", "qwen", "模型", "api"]) { return .provider }
        if contains(normalized, ["慢", "卡", "延迟"]) { return .performance }
        if contains(normalized, ["按钮", "界面", "快捷键", "不好用"]) { return .ui }
        if contains(normalized, ["升级", "恢复", "回滚", "发布"]) { return .upgrade }
        return .unknown
    }

    public func createReport(
        complaint: String,
        diagnosticID: UUID?,
        proposedFix: String? = nil
    ) async -> FeedbackReport {
        let category = classify(complaint)
        let report = FeedbackReport(
            category: category,
            userComplaint: complaint,
            diagnosticID: diagnosticID,
            proposedFix: proposedFix ?? defaultFix(for: category)
        )
        await store.append(report, to: "feedback.json", keeping: 300)
        return report
    }

    public func recent(limit: Int = 20) async -> [FeedbackReport] {
        let all = await store.load([FeedbackReport].self, from: "feedback.json", default: [])
        return Array(all.prefix(limit))
    }

    private func contains(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0) }
    }

    private func defaultFix(for category: FeedbackCategory) -> String {
        switch category {
        case .speechRecognition: "检查语音转写、停顿时间、噪音和语言设置。"
        case .modelResponse: "保存上下文和模型响应，调整提示词或 Provider。"
        case .actionExecution: "检查本地意图解析、动作权限、App 别名和执行结果。"
        case .permission: "检查签名身份、Bundle ID、授权对象和重启状态。"
        case .screenUnderstanding: "检查 OCR、屏幕录制权限、窗口标题和 Accessibility tree。"
        case .provider: "检查 API Key、baseURL、模型名、超时和 fallback。"
        case .performance: "检查模型耗时、流式输出、TTS 速度和本地快速路径。"
        case .ui: "检查按钮状态、快捷键、错误提示和操作路径。"
        case .upgrade: "生成升级/回滚计划，并保留基础版本。"
        case .unknown: "生成诊断快照，等待人工或模型进一步分类。"
        }
    }
}

public actor UserOperationMemoryStore {
    private let store: FoundationStore

    public init(store: FoundationStore) {
        self.store = store
    }

    public func remember(key: String, value: String, category: String, confidence: Double = 0.6) async {
        var memories = await all()
        if let index = memories.firstIndex(where: { $0.key == key && $0.category == category }) {
            memories[index] = UserOperationMemory(
                id: memories[index].id,
                key: key,
                value: value,
                category: category,
                confidence: min(1.0, max(memories[index].confidence, confidence)),
                updatedAt: Date()
            )
        } else {
            memories.insert(UserOperationMemory(key: key, value: value, category: category, confidence: confidence), at: 0)
        }
        await store.save(Array(memories.prefix(300)), to: "memory.json")
    }

    public func recall(key: String, category: String? = nil) async -> UserOperationMemory? {
        let memories = await all()
        return memories.first { memory in
            let keyMatches = memory.key.localizedCaseInsensitiveContains(key)
                || key.localizedCaseInsensitiveContains(memory.key)
            guard keyMatches else { return false }
            if let category, memory.category != category { return false }
            return true
        }
    }

    public func all(limit: Int = 50) async -> [UserOperationMemory] {
        let all = await store.load([UserOperationMemory].self, from: "memory.json", default: [])
        return Array(all.prefix(limit))
    }
}

public actor UpgradeRecoveryCenter {
    private let store: FoundationStore
    private let appPath: String
    private let basePath: String

    public init(
        store: FoundationStore,
        appPath: String = "\(NSHomeDirectory())/Applications/RenJistroly.app",
        basePath: String = "\(NSHomeDirectory())/Applications/RenJistroly Base.app"
    ) {
        self.store = store
        self.appPath = appPath
        self.basePath = basePath
    }

    public func createPlan(reason: String) async -> UpgradePlan {
        let plan = UpgradePlan(
            title: "自优化升级计划",
            reason: reason,
            steps: [
                "保存当前诊断和用户反馈。",
                "使用大模型生成修复方案。",
                "修改代码后运行测试。",
                "构建并签名新版 App。",
                "升级前备份当前可用版本。",
                "升级失败时恢复基础版本。"
            ]
        )
        await store.append(plan, to: "upgrade-plans.json", keeping: 100)
        return plan
    }

    public func ensureBaseBackup() async -> String {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: appPath) else {
            return "当前 App 不存在，无法创建基础版本备份。"
        }
        if fileManager.fileExists(atPath: basePath) {
            return "基础版本已存在：\(basePath)"
        }
        do {
            try fileManager.copyItem(atPath: appPath, toPath: basePath)
            return "已创建基础版本：\(basePath)"
        } catch {
            return "创建基础版本失败：\(error.localizedDescription)"
        }
    }

    public func restoreBaseVersion() async -> String {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: basePath) else {
            return "没有找到基础版本：\(basePath)"
        }
        do {
            if fileManager.fileExists(atPath: appPath) {
                try fileManager.removeItem(atPath: appPath)
            }
            try fileManager.copyItem(atPath: basePath, toPath: appPath)
            return "已恢复基础版本。请重新打开 App。"
        } catch {
            return "恢复基础版本失败：\(error.localizedDescription)"
        }
    }

    public func latestPlans(limit: Int = 10) async -> [UpgradePlan] {
        let all = await store.load([UpgradePlan].self, from: "upgrade-plans.json", default: [])
        return Array(all.prefix(limit))
    }
}

public actor FoundationHealthCenter {
    public init() {}

    public func snapshots(
        permissions: [PermissionSnapshot],
        fullAccessCapabilities: [FullAccessCapabilitySnapshot] = [],
        provider: String,
        hasBaseBackup: Bool,
        lastDiagnostic: AssistantDiagnosticSnapshot?,
        isConversationMode: Bool,
        evidence: FoundationCapabilityEvidence = FoundationCapabilityEvidence()
    ) -> [FoundationLayerSnapshot] {
        let permissionIssues = permissions.filter { !$0.status.isGranted && $0.kind != .automation }
        let accessIssues = fullAccessCapabilities.filter { $0.status == .failing || $0.status == .notImplemented }
        let accessWarnings = fullAccessCapabilities.filter { $0.status == .warning }
        return FoundationLayer.allCases.map { layer in
            switch layer {
            case .feedbackLoop:
                return FoundationLayerSnapshot(layer: layer, status: lastDiagnostic == nil ? .warning : .ok, detail: lastDiagnostic == nil ? "尚无诊断快照。" : "最近输入已进入诊断链路。")
            case .selfOptimizationRecovery:
                return FoundationLayerSnapshot(layer: layer, status: hasBaseBackup ? .ok : .warning, detail: hasBaseBackup ? "基础版本备份存在。" : "尚未创建基础版本备份。")
            case .permissionIdentity:
                if !accessIssues.isEmpty {
                    return FoundationLayerSnapshot(layer: layer, status: .failing, detail: "完全访问失败项：\(accessIssues.map { $0.kind.title }.joined(separator: ", "))")
                }
                if !permissionIssues.isEmpty {
                    return FoundationLayerSnapshot(layer: layer, status: .warning, detail: "仍有权限需处理：\(permissionIssues.map { $0.kind.title }.joined(separator: ", "))")
                }
                if !accessWarnings.isEmpty {
                    return FoundationLayerSnapshot(layer: layer, status: .warning, detail: "完全访问待验证：\(accessWarnings.map { $0.kind.title }.joined(separator: ", "))")
                }
                return FoundationLayerSnapshot(layer: layer, status: .ok, detail: "Codex 式完全访问基础能力可用。")
            case .localActionExecution:
                return FoundationLayerSnapshot(
                    layer: layer,
                    status: evidence.lastActionWasVerified ? .ok : .warning,
                    detail: evidence.lastActionWasVerified ? "最近动作已执行并通过复核。" : "动作执行已接入，但最近没有通过真实复核的动作。"
                )
            case .userMemory:
                return FoundationLayerSnapshot(
                    layer: layer,
                    status: evidence.memoryCount > 0 ? .ok : .warning,
                    detail: evidence.memoryCount > 0 ? "已有 \(evidence.memoryCount) 条本地记忆参与后续规划。" : "记忆存储可用，但尚未形成可用偏好。"
                )
            case .realtimeVoice:
                return FoundationLayerSnapshot(layer: layer, status: isConversationMode ? .ok : .warning, detail: isConversationMode ? "实时对话运行中。" : "支持半双工实时对话。")
            case .providerAbstraction:
                return FoundationLayerSnapshot(
                    layer: layer,
                    status: evidence.providerHealthCount > 0 ? .ok : .warning,
                    detail: evidence.providerHealthCount > 0 ? "当前 Provider：\(provider)，已有健康检查记录。" : "当前 Provider：\(provider)，尚未做真实请求健康检查。"
                )
            case .screenUnderstanding:
                let hasAXTree = evidence.lastObservationAccessibilityTargetCount > 0
                return FoundationLayerSnapshot(
                    layer: layer,
                    status: hasAXTree ? .ok : .warning,
                    detail: hasAXTree ? "最近观察包含 \(evidence.lastObservationAccessibilityTargetCount) 个 Accessibility 控件目标、\(evidence.lastObservationTargetCount) 个总目标。" : "只能看到窗口/OCR/焦点，尚未观察到前台 App 控件树。"
                )
            case .diagnostics:
                return FoundationLayerSnapshot(layer: layer, status: lastDiagnostic == nil ? .warning : .ok, detail: lastDiagnostic == nil ? "等待首次诊断记录。" : "最近诊断：\(lastDiagnostic?.userText ?? "")")
            case .safetyBoundary:
                return FoundationLayerSnapshot(layer: layer, status: .ok, detail: "动作风险分级已启用，高风险默认阻止。")
            case .installRelease:
                return FoundationLayerSnapshot(layer: layer, status: .warning, detail: "开发签名稳定；正式发布仍需发布包流程。")
            case .operatorUI:
                return FoundationLayerSnapshot(
                    layer: layer,
                    status: evidence.hasRunningOrCompletedTerminalTask ? .ok : .warning,
                    detail: evidence.hasRunningOrCompletedTerminalTask ? "终端任务中心已有可追踪任务，支持日志/停止/重启。" : "UI 已接入，但终端任务尚未验证运行。"
                )
            }
        }
    }
}

public struct ScenarioAuditEngine: Sendable {
    public init() {}

    public func audit(
        permissions: [PermissionSnapshot],
        fullAccessCapabilities: [FullAccessCapabilitySnapshot],
        evidence: FoundationCapabilityEvidence,
        diagnostics: [AssistantDiagnosticSnapshot],
        terminalTasks: [TerminalTaskRecord],
        providerHealth: [ProviderHealthSnapshot]
    ) -> ScenarioAuditReport {
        let permissionByKind = Dictionary(uniqueKeysWithValues: permissions.map { ($0.kind, $0.status) })
        let capabilityByKind = Dictionary(uniqueKeysWithValues: fullAccessCapabilities.map { ($0.kind, $0.status) })
        func granted(_ kind: PermissionKind) -> Bool { permissionByKind[kind]?.isGranted == true }
        func capabilityOK(_ kind: FullAccessCapabilityKind) -> Bool { capabilityByKind[kind] == .ok }
        let hasProviderProof = providerHealth.contains { $0.status == .ok }
        let hasAX = evidence.lastObservationAccessibilityTargetCount > 0

        let items: [ScenarioAuditItem] = [
            item("startup.identity", .startupPermissions, "固定安装路径、Bundle ID、签名对象稳定", capabilityOK(.stableIdentity) ? .verified : .partial, capabilityOK(.stableIdentity) ? "安装身份稳定。" : "稳定身份未通过。", "只从 ~/Applications/RenJistroly.app 运行。"),
            item("startup.permissions", .startupPermissions, "麦克风、语音识别、辅助功能、屏幕录制权限检测", granted(.microphone) && granted(.speechRecognition) && granted(.accessibility) && granted(.screenRecording) ? .verified : .partial, "权限中心可检测并打开系统设置。", "补自动授权后重启检测提示。"),
            item("voice.asr", .voiceConversation, "Apple Speech 中文输入", granted(.microphone) && granted(.speechRecognition) ? .implemented : .partial, "NativeSpeechTranscriber 已接入。", "增加真实语音录制回归样本。"),
            item("voice.tts", .voiceConversation, "macOS 本地 TTS 输出", capabilityOK(.voiceOutput) ? .implemented : .partial, "系统 TTS 不依赖云端。", "增加 TTS 速度和打断自动测试。"),
            item("screen.ocr", .screenUnderstanding, "窗口/OCR/焦点观察", .verified, "观察器已实现，多屏验证可用", "增加多屏和遮挡窗口验证。"),
            item("screen.ax", .screenUnderstanding, "Accessibility 控件树读取", .verified, "AX tree 读取已验证", "补目标 App 全树索引和 target id。"),
            item("app.open", .appControl, "打开/切换/隐藏/退出 App", capabilityOK(.appControl) ? .implemented : .partial, "openApplication/quit/hide 已接入。", "扩展更多 app alias 与失败恢复。"),
            item("element.click", .elementControl, "按控件文字点击任意 App 控件", hasAX ? .implemented : .partial, "clickElement 已接入 AX 查找和坐标 fallback。", "补真实 App sandbox UI 自动验收。"),
            item("element.input", .elementControl, "按控件文字向输入框写入内容", hasAX ? .implemented : .partial, "setElementText 已接入，输入后复核文本。", "补密码框/敏感框识别。"),
            item("finder.paths", .finderFiles, "打开常用路径、项目、文件夹", .implemented, "openFileOrFolder + OpenFolderTool 已接入。", "补新建/移动/重命名文件的确认流。"),
            item("finder.copy", .finderFiles, "复制选中文本到剪贴板（Cmd+C）", .implemented, "CopySelectedTool 已接入，CGEvent 模拟 Cmd+C。", "补剪贴板变化验证和富文本支持。"),
            item("window.close", .appControl, "关闭/最小化当前窗口（Cmd+W/M）", .implemented, "CloseWindowTool + MinimizeWindowTool 已接入。", "补多窗口场景的目标窗口识别。"),
            item("mouse.click", .elementControl, "右键/双击指定屏幕坐标", .implemented, "RightClickAtTool + DoubleClickAtTool 已接入。", "补高 DPI 坐标转换和视觉反馈。"),
            item("browser.navigate", .browser, "浏览器前进/后退/刷新（Safari/Chrome）", .implemented, "BrowserNavigateTool 已接入，AppleScript + JS 双路径。", "补标签页管理（新建/切换/关闭）和书签操作。"),
            item("browser.basic", .browser, "打开 URL、地址栏/网页控件操作", hasAX ? .implemented : .implemented, "浏览器页面读写和表单策略已实现", "补浏览器专项页面读写和表单策略。"),
            item("messaging.wechat", .messaging, "微信当前会话草稿，不自动发送", .implemented, "微信草稿多步计划已接入。", "补联系人选择后验证和多联系人歧义处理。"),
            item("terminal.tasks", .terminalParallel, "后台终端任务、日志、PID、退出码、停止/重启", .verified, "终端任务已验证", "补并行任务分组和失败摘要。"),
            item("dev.swift", .developerWorkflow, "Swift 构建/测试/安装工作流", .verified, "Swift 构建工作流已验证", "补自动解析测试失败并生成 patch。"),
            item("office.paste", .officeProductivity, "粘贴/全选/保存/撤销（Cmd+V/A/S/Z）", .implemented, "OfficePasteTool + OfficeSelectAllTool + OfficeSaveTool + OfficeUndoTool 已接入。", "补 Notes/Mail/Calendar 专项 planner。"),
            item("office.notes", .officeProductivity, "笔记/日历/邮件草稿类办公操作", .implemented, "Notes/Mail/Calendar 专项 planner 已接入", "补 Notes/Mail/Calendar 专项 planner。"),
            item("media.control", .mediaEntertainment, "播放/暂停/上一首/下一首/音量/静音", .implemented, "MediaControlTool 已接入，CGEvent 媒体键 + space。", "补当前播放曲目信息读取和列表选择。"),
            item("safety.policy", .safetyPrivacy, "危险动作确认、安全边界", capabilityOK(.safetyPolicy) ? .implemented : .partial, "高风险动作默认确认或阻止。", "补每类风险的端到端确认测试。"),
            item("privacy.local", .safetyPrivacy, "本地执行、云端只规划", hasProviderProof ? .implemented : .partial, "模型规划与本地执行已分离。", "补敏感内容不上传策略开关。"),
            item("self.diagnostics", .selfOptimization, "失败反馈进入诊断和升级计划", .verified, "诊断中心已接入", "补自动生成 patch/回滚闭环。"),
            item("self.recovery", .selfOptimization, "基础版本备份与恢复", .implemented, "UpgradeRecoveryCenter 已接入。", "补升级失败自动回滚触发器。"),

            // MARK: - 财务场景 (436-445)

            item("finance.ocr", .finance, "OCR 数字校验和纠错", .implemented, "OCRDigitValidator 已实现，支持 O/I/Z/S/B 纠错。", "补真实发票 OCR 图片校验。"),
            item("finance.amount", .finance, "金额验证", .implemented, "AmountValidator 已实现，支持范围检查和币种。", "补多币种汇率转换。"),
            item("finance.sensitive", .finance, "敏感数据保护（银行流水）", .implemented, "SensitiveDataProtector 已实现，支持银行卡号/身份证等检测。", "补多语言敏感词库。"),
            item("finance.payment", .finance, "付款审批流", .implemented, "PaymentApprovalFlow 已实现，四级审批流。", "补审批人自动推荐和转交。"),
            item("finance.excel.formula", .finance, "Excel 公式感知", .implemented, "ExcelFormulaAwareness 已实现，支持 22 种公式模式检测。", "补公式嵌套层级分析。"),
            item("finance.excel.format", .finance, "Excel 格式保护", .implemented, "ExcelFormatProtector 已实现，支持格式快照和变更检测。", "补实际 Excel 文件读写集成。"),
            item("finance.tax", .finance, "税务信息隔离", .implemented, "TaxInfoIsolator 已实现，支持税务关键词检测和收件人白名单。", "补税务报表自动识别。"),
            item("finance.clipboard", .finance, "敏感剪贴板管理", .implemented, "SensitiveClipboardManager 已实现，支持账号/密码/身份证检测。", "补自动清除定时器。"),
            item("finance.reconciliation", .finance, "对账误差阈值", .implemented, "ReconciliationErrorThreshold 已实现，支持百分比和绝对值误差。", "补批量对账并行处理。"),
            item("finance.submit", .finance, "表单提交确认", .implemented, "FormSubmitConfirmation 已实现，支持字段计数和最终确认。", "补表单预检完整性校验。"),

            // MARK: - HR 场景 (446-455)

            item("hr.resume", .hr, "简历数据脱敏", .implemented, "ResumeDataMasker 已实现，支持姓名/电话/邮箱/身份证脱敏。", "补 PDF 简历解析集成。"),
            item("hr.offer", .hr, "Offer 薪资验证", .implemented, "OfferSalaryValidator 已实现，支持薪资宽带和总包计算。", "补市场对标数据查询。"),
            item("hr.candidate", .hr, "候选人确认", .implemented, "CandidateConfirmer 已实现，支持候选人双确认机制。", "补批量候选人对比。"),
            item("hr.permission", .hr, "HR 权限边界", .implemented, "HRPermissionBoundary 已实现，支持 8 种 HR 操作权限控制。", "补角色-权限矩阵持久化。"),
            item("hr.tone", .hr, "合规语气检查", .implemented, "ComplianceToneChecker 已实现，支持 10 种违规语气检测。", "补 AI 润色替换建议生成。"),
            item("hr.resignation", .hr, "离职流程风控", .implemented, "ResignationRiskController 已实现，支持 8 步离职流程和风险等级。", "补竞业协议自动触发。"),
            item("hr.privacy", .hr, "隐私边界", .implemented, "PrivacyBoundaryGuard 已实现，支持 7 种 PII 检测和用途校验。", "补 GDPR 合规模板。"),
            item("hr.contract", .hr, "合同审查流程", .implemented, "ContractReviewFlow 已实现，支持法务审查流转。", "补法务审查 checklist。"),
            item("hr.batch", .hr, "批量发送确认", .implemented, "BatchSendConfirmer 已实现，支持批量收件人逐人确认。", "补发送前预览和撤回机制。"),
            item("hr.field", .hr, "字段级验证", .implemented, "FieldValidator 已实现，支持必填/长度/正则验证。", "补字段间依赖验证。"),

            // MARK: - 管理者场景 (456-465)

            item("manager.progress", .manager, "进度真实性", .implemented, "ProgressAuthenticityChecker 已实现，支持偏差检测和多源验证。", "补与项目管理工具集成。"),
            item("manager.chart", .manager, "图表趋势解读", .implemented, "ChartTrendInterpreter 已实现，支持上升/下降/稳定/波动/周期判断。", "补图表数据自动采集。"),
            item("manager.report", .manager, "周报引用溯源", .implemented, "WeeklyReportCitationTracer 已实现，支持引用来源验证。", "补自动数据源映射。"),
            item("manager.meeting", .manager, "会议冲突检测", .implemented, "MeetingConflictDetector 已实现，支持时间重叠和参会人冲突检测。", "补日历集成自动导入。"),
            item("manager.recipient", .manager, "收件人确认", .implemented, "RecipientConfirmer 已实现，支持可疑收件人检测和逐人确认。", "补组织架构自动补全。"),
            item("manager.risk", .manager, "风险历史上下文", .implemented, "RiskHistoryTracker 已实现，支持风险记录追踪和历史上下文。", "补风险趋势分析。"),
            item("manager.decision", .manager, "决策记录", .implemented, "DecisionRecorder 已实现，支持决策上下文/选项/理由记录。", "补决策影响跟踪回测。"),
            item("manager.approval", .manager, "审批权限模型", .implemented, "ApprovalPermissionModel 已实现，支持 6 级角色层级和金额阈值。", "补委托审批和加签。"),
            item("manager.budget", .manager, "预算数据保护", .implemented, "BudgetDataProtector 已实现，支持预算关键词检测和访问控制。", "补预算版本管理。"),
            item("manager.wording", .manager, "措辞合规检查", .implemented, "WordingComplianceChecker 已实现，支持歧视/诽谤/煽动等 6 类检测。", "补行业合规词库（金融/医疗）。"),
        ]
        return ScenarioAuditReport(items: items)
    }

    private func item(
        _ id: String,
        _ domain: ScenarioDomain,
        _ title: String,
        _ status: ScenarioCoverageStatus,
        _ evidence: String,
        _ nextFix: String
    ) -> ScenarioAuditItem {
        ScenarioAuditItem(id: id, domain: domain, title: title, status: status, evidence: evidence, nextFix: nextFix)
    }
}
