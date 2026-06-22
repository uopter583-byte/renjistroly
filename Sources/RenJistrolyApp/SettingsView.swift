import SwiftUI
import OSLog
import RenJistrolyIntelligence
import RenJistrolyModels
import RenJistrolyConversation
import RenJistrolySystemBridge

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ConversationEngine.self) private var engine

    @State private var anthropicKey: String = ""
    @State private var openAIKey: String = ""
    @State private var deepseekKey: String = ""
    @State private var claudeCodePath: String = ""
    @State private var claudeTaskPrompt: String = ""
    @State private var permissionChecks: [SystemPermissionKind: SystemPermissionCheck] = [:]
    @State private var isRefreshingPermissions: Bool = false

    private var hotkeyBinding: Binding<Bool> {
        Binding(get: { appState.isHotkeyEnabled }, set: { appState.isHotkeyEnabled = $0 })
    }
    private var voiceOutputBinding: Binding<Bool> {
        Binding(get: { appState.isVoiceOutputEnabled }, set: { appState.isVoiceOutputEnabled = $0 })
    }
    private var continuousVoiceBinding: Binding<Bool> {
        Binding(get: { appState.isContinuousVoiceModeEnabled }, set: { appState.isContinuousVoiceModeEnabled = $0 })
    }
    private var providerBinding: Binding<LLMProvider> {
        Binding(get: { appState.activeProvider }, set: {
            appState.activeProvider = $0
            syncControllerProvider(to: $0)
        })
    }
    private func syncControllerProvider(to provider: LLMProvider) {
        let pref: ProviderPreference = switch provider {
        case .claudeCodeCLI: .claudeCode
        case .deepseek: .deepSeek
        case .localMLX, .ollama: .localEndpoint
        case .custom: .localFirst
        default: .deepSeek
        }
        if AssistantSessionController.shared.providerPreference != pref {
            AssistantSessionController.shared.providerPreference = pref
        }
    }

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("通用", systemImage: "gearshape") }

            providerSettings
                .tabItem { Label("AI 模型", systemImage: "brain") }

            toolSafetySettings
                .tabItem { Label("安全", systemImage: "shield.checkered") }

            developerSettings
                .tabItem { Label("开发者", systemImage: "hammer") }

            permissionsSettings
                .tabItem { Label("权限", systemImage: "lock.shield") }

            aboutSettings
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 400)
        .task {
            if let savedPath = appState.devMode.claudeCodePath {
                claudeCodePath = savedPath
            } else {
                await engine.refreshClaudeCodeStatus()
                claudeCodePath = engine.claudeCodeStatus.executablePath
                appState.devMode.claudeCodePath = claudeCodePath
            }
            await refreshPermissions()
        }
    }

    // MARK: - General

    private var generalSettings: some View {
        Form {
            Section("启动与外观") {
                Toggle("开机自动启动", isOn: .constant(false))
                Toggle("在菜单栏显示图标", isOn: .constant(true))
                Toggle("启用浮动面板", isOn: hotkeyBinding)
            }

            Section("默认 AI 提供者") {
                Picker("默认模型", selection: providerBinding) {
                    ForEach(LLMProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
            }

            Section("交互") {
                Toggle("启用语音回复", isOn: voiceOutputBinding)
                Toggle("连续语音模式", isOn: continuousVoiceBinding)

                HStack {
                    Text("全局热键")
                    Spacer()
                    Text("按住 ⌥ Space")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }

                Picker("语音语言", selection: .constant("zh-CN")) {
                    Text("中文").tag("zh-CN")
                    Text("English").tag("en-US")
                    Text("日本語").tag("ja-JP")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tool Safety

    private var toolSafetySettings: some View {
        Form {
            Section("工具自动执行策略") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("控制 AI 助手执行系统操作时是否需要确认。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Toggle(isOn: autoApproveLowBinding) {
                    VStack(alignment: .leading) {
                        Text("低风险 · 自动执行")
                            .font(.system(size: 13, weight: .medium))
                        Text("只读操作：读取文件、列出目录、系统信息、Git状态等")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: autoApproveMediumBinding) {
                    VStack(alignment: .leading) {
                        Text("中风险 · 自动执行")
                            .font(.system(size: 13, weight: .medium))
                        Text("UI交互：打开应用、点击元素、按键、菜单导航等")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: autoApproveHighBinding) {
                    VStack(alignment: .leading) {
                        Text("高风险 · 自动执行")
                            .font(.system(size: 13, weight: .medium))
                        Text("系统修改：写入文件、Shell命令、文字输入、拖拽等")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.red)
            }

            Section("预设") {
                HStack(spacing: 12) {
                    policyPresetButton("默认", policy: .default, description: "低风险自动，中高风险确认")
                    policyPresetButton("宽松", policy: .permissive, description: "低中风险自动，仅高风险确认")
                    policyPresetButton("严格", policy: .strict, description: "全部需要确认")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func policyPresetButton(_ label: String, policy: ToolExecutionPolicy, description: String) -> some View {
        Button {
            appState.toolExecutionPolicy = policy
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Text(description)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                appState.toolExecutionPolicy == policy
                    ? Color.accentColor.opacity(0.15)
                    : Color.secondary.opacity(0.05)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var autoApproveLowBinding: Binding<Bool> {
        Binding(
            get: { appState.toolExecutionPolicy.autoApproveLow },
            set: { appState.toolExecutionPolicy.autoApproveLow = $0 }
        )
    }
    private var autoApproveMediumBinding: Binding<Bool> {
        Binding(
            get: { appState.toolExecutionPolicy.autoApproveMedium },
            set: { appState.toolExecutionPolicy.autoApproveMedium = $0 }
        )
    }
    private var autoApproveHighBinding: Binding<Bool> {
        Binding(
            get: { appState.toolExecutionPolicy.autoApproveHigh },
            set: { appState.toolExecutionPolicy.autoApproveHigh = $0 }
        )
    }

    // MARK: - Provider

    private var providerSettings: some View {
        Form {
            Section("Anthropic (Claude)") {
                SecureField("API Key", text: $anthropicKey)
                    .onChange(of: anthropicKey) { _, newValue in
                        Task { await engine.configureCloudAPI(provider: .anthropic, key: newValue) }
                    }
                Text("获取 API Key: console.anthropic.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("OpenAI") {
                SecureField("API Key", text: $openAIKey)
                    .onChange(of: openAIKey) { _, newValue in
                        Task { await engine.configureCloudAPI(provider: .openAI, key: newValue) }
                    }
                Text("获取 API Key: platform.openai.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("DeepSeek") {
                SecureField("API Key", text: $deepseekKey)
                    .onChange(of: deepseekKey) { _, newValue in
                        Task { await engine.configureCloudAPI(provider: .deepseek, key: newValue) }
                    }
                Text("获取 API Key: platform.deepseek.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("本地模型 (MLX)") {
                HStack {
                    Text("状态")
                    Spacer()
                    Text("Apple Silicon · 可用")
                        .foregroundColor(.green)
                }
                Text("本地模型在 Apple Silicon 上运行，无需联网，数据安全")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Developer

    private var devModeBinding: Binding<Bool> {
        Binding(get: { appState.devMode.isEnabled }, set: { appState.devMode.isEnabled = $0 })
    }
    private var ocrEngineBinding: Binding<OCREngine> {
        Binding(get: { appState.ocrEngine }, set: { appState.ocrEngine = $0 })
    }

    private var developerSettings: some View {
        Form {
            Section("开发者模式") {
                Toggle("启用开发者模式", isOn: devModeBinding)

                if appState.devMode.isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("项目路径")
                            .font(.system(size: 12, weight: .medium))
                        HStack {
                            Text(appState.devMode.projectPath ?? contextCompilerPath)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Button("检测") {
                                appState.devMode.projectPath = engine.contextCompiler.currentContext?.rootPath
                            }
                            .font(.system(size: 11))
                        }
                    }
                }
            }

            if appState.devMode.isEnabled {
                Section("OCR 引擎") {
                    Picker("文字识别引擎", selection: ocrEngineBinding) {
                        ForEach(OCREngine.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                }

                Section("Claude Code") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: engine.claudeCodeStatus.isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(engine.claudeCodeStatus.isInstalled ? .green : .orange)
                            Text(engine.claudeCodeStatus.isInstalled ? "Claude Code 已可用" : "Claude Code 未检测到")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Button("刷新") {
                                Task { await syncClaudeCodePath() }
                            }
                            .font(.system(size: 11))
                        }

                        TextField("/opt/homebrew/bin/claude", text: $claudeCodePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .onSubmit {
                                Task { await syncClaudeCodePath() }
                            }

                        HStack {
                            Text("当前项目")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(appState.devMode.projectPath ?? contextCompilerPath)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        TextField("给 Claude Code 的任务，例如：阅读当前 Swift Package 并总结未完成的能力", text: $claudeTaskPrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)

                        HStack {
                            Button("保存路径") {
                                Task { await syncClaudeCodePath() }
                            }

                            Button("启动 Claude 任务") {
                                let prompt = claudeTaskPrompt
                                claudeTaskPrompt = ""
                                Task { await engine.launchClaudeCodeTask(prompt, appState: appState) }
                            }
                            .disabled(claudeTaskPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !engine.claudeCodeStatus.isInstalled)
                        }

                        Text(engine.claudeCodeStatus.isInstalled
                             ? "Claude Code 会在当前项目目录中执行开发任务，并把输出流式返回到对话区。"
                             : "请确认 Claude Code CLI 已安装，并把可执行文件路径填写到上方。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Section("快速操作") {
                    HStack {
                        Button {
                            Task {
                                let result = await engine.buildProject(appState: appState)
                                await engine.sendMessage("构建完成: \(result.summary)", appState: appState)
                            }
                        } label: {
                            Label("构建", systemImage: "hammer")
                        }

                        Button {
                            Task {
                                let result = await engine.runTests(appState: appState)
                                await engine.sendMessage("测试完成: \(result.summary)", appState: appState)
                            }
                        } label: {
                            Label("测试", systemImage: "checklist")
                        }
                    }

                    if let build = appState.devMode.lastBuildResult {
                        buildStatusRow(build)
                    }
                    if let test = appState.devMode.lastTestResult {
                        testStatusRow(test)
                    }
                }

                Section("Self-Update") {
                    HStack {
                        Image(systemName: helperStatusIcon)
                            .foregroundColor(helperStatusColor)
                        Text("Helper: \(helperStatusText)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Button("检查") {
                            Task { await updateManager?.checkHelperStatus() }
                        }
                        .font(.system(size: 11))
                    }

                    HStack {
                        Text("当前版本")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("0.1.0")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Button {
                            _ = updateManager?.installHelper()
                        } label: {
                            Label("安装 Helper", systemImage: "gearshape.2")
                        }
                        .font(.system(size: 11))

                        Button {
                            Task {
                                let (ok, msg) = await updateManager?.verifySignature(
                                    of: Bundle.main.bundlePath
                                ) ?? (false, "无响应")
                                #if DEBUG
                                Logger.app.log("[SettingsView] 签名验证: \(ok ? "OK" : "FAIL", privacy: .public) — \(msg, privacy: .public)")
                                #endif
                            }
                        } label: {
                            Label("验证签名", systemImage: "checkmark.seal")
                        }
                        .font(.system(size: 11))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updateManager: UpdateManager? {
        (NSApp.delegate as? AppDelegate)?.updateManager
    }

    private var helperStatusIcon: String {
        guard let status = updateManager?.helperStatus else { return "exclamationmark.circle.fill" }
        switch status {
        case .unknown: return "questionmark.circle.fill"
        case .notInstalled: return "xmark.circle.fill"
        case .installed: return "checkmark.circle.fill"
        case .installing: return "arrow.triangle.2.circlepath.circle.fill"
        case .connected: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private var helperStatusColor: Color {
        guard let status = updateManager?.helperStatus else { return .secondary }
        switch status {
        case .unknown: return .secondary
        case .notInstalled: return .orange
        case .installed: return .green
        case .installing: return .blue
        case .connected: return .green
        case .error: return .red
        }
    }

    private var helperStatusText: String {
        guard let status = updateManager?.helperStatus else { return "未知" }
        switch status {
        case .unknown: return "未知"
        case .notInstalled: return "未安装"
        case .installed: return "已安装"
        case .installing: return "安装中..."
        case .connected: return "已连接"
        case .error(let msg): return "错误: \(msg.prefix(30))"
        }
    }

    private var contextCompilerPath: String {
        engine.contextCompiler.currentContext?.rootPath ?? "未检测到项目"
    }

    private func syncClaudeCodePath() async {
        await engine.setClaudeCodePath(claudeCodePath, appState: appState)
        claudeCodePath = engine.claudeCodeStatus.executablePath
    }

    private func buildStatusRow(_ result: BuildResult) -> some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            Text("最近构建: \(result.summary)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func testStatusRow(_ result: TestResult) -> some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            Text("最近测试: \(result.summary)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Permissions

    private var permissionsSettings: some View {
        Form {
            Section {
                HStack {
                    Text("权限状态")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button {
                        Task { await refreshPermissions() }
                    } label: {
                        if isRefreshingPermissions {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshingPermissions)
                }
            }

            Section("系统权限") {
                ForEach(SystemPermissionKind.allCases) { kind in
                    PermissionRow(
                        check: permissionChecks[kind] ?? SystemPermissionCheck(
                            kind: kind,
                            status: .unknown,
                            detail: "尚未刷新。"
                        ),
                        requestAction: {
                            Task { await requestPermission(kind) }
                        },
                        openSettingsAction: {
                            PermissionCenter.shared.openSystemSettings(for: kind)
                        }
                    )
                }
            }

            Section("隐私") {
                Text("所有语音处理在本地完成，对话敏感数据不会离开设备。云端 API 调用仅发送必要的对话内容，且完全由您控制的 API Key 完成。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func refreshPermissions() async {
        isRefreshingPermissions = true
        let checks = await PermissionCenter.shared.checkSystemPermissions()
        permissionChecks = Dictionary(uniqueKeysWithValues: checks.map { ($0.kind, $0) })
        applyPermissionChecks(checks)
        isRefreshingPermissions = false
    }

    private func requestPermission(_ kind: SystemPermissionKind) async {
        let check = await PermissionCenter.shared.requestSystemPermission(kind)
        permissionChecks[kind] = check
        applyPermissionChecks([check])
        if !check.status.isGranted, let _ = kind.settingsURL {
            PermissionCenter.shared.openSystemSettings(for: kind)
        }
    }

    private func applyPermissionChecks(_ checks: [SystemPermissionCheck]) {
        AppDelegate.applyPermissionChecks(checks, to: appState)
    }

    // MARK: - About

    private var aboutSettings: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("RenJistroly")
                .font(.system(size: 28, weight: .bold))

            Text("版本 0.1.0")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("macOS 原生智能助手")
                .font(.system(size: 16))

            Text("本地 Apple Silicon AI + 云端大模型\n系统控制 · 代码辅助 · 自然对话")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("macOS 15+ · Apple Silicon")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PermissionRow: View {
    let check: SystemPermissionCheck
    let requestAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 16))
                .frame(width: 20)

            VStack(alignment: .leading) {
                Text(check.kind.title)
                    .font(.system(size: 13, weight: .medium))
                Text(check.kind.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                if !check.detail.isEmpty {
                    Text(check.detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(check.status.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor)

                if !check.status.isGranted {
                    HStack(spacing: 6) {
                        Button("请求") {
                            requestAction()
                        }
                        .font(.system(size: 11))

                        Button("设置") {
                            openSettingsAction()
                        }
                        .font(.system(size: 11))
                    }
                }
            }
        }
    }

    private var statusIcon: String {
        switch check.status {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined: "questionmark.circle.fill"
        case .unknown: "exclamationmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch check.status {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .orange
        case .unknown: .secondary
        }
    }
}
