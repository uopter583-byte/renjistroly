import SwiftUI
import OSLog
import RenJistrolyIntelligence
import RenJistrolyModels
import RenJistrolyConversation
import RenJistrolySystemBridge
import RenJistrolyUI

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
                .tabItem { Label(RenJistrolyStrings.text("settingsTabGeneral"), systemImage: "gearshape") }

            providerSettings
                .tabItem { Label(RenJistrolyStrings.text("settingsTabAIModel"), systemImage: "brain") }

            toolSafetySettings
                .tabItem { Label(RenJistrolyStrings.text("settingsTabSecurity"), systemImage: "shield.checkered") }

            developerSettings
                .tabItem { Label(RenJistrolyStrings.text("settingsTabDeveloper"), systemImage: "hammer") }

            permissionsSettings
                .tabItem { Label(RenJistrolyStrings.text("settingsTabPermissions"), systemImage: "lock.shield") }

            aboutSettings
                .tabItem { Label(RenJistrolyStrings.text("settingsTabAbout"), systemImage: "info.circle") }
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
            Section(RenJistrolyStrings.text("settingsGeneralStartupAppearance")) {
                Toggle(RenJistrolyStrings.text("settingsLaunchAtLogin"), isOn: .constant(false))
                Toggle(RenJistrolyStrings.text("settingsShowMenuBarIcon"), isOn: .constant(true))
                Toggle(RenJistrolyStrings.text("settingsEnableFloatingPanel"), isOn: hotkeyBinding)
            }

            Section(RenJistrolyStrings.text("settingsDefaultAIProvider")) {
                Picker(RenJistrolyStrings.text("settingsDefaultModel"), selection: providerBinding) {
                    ForEach(LLMProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
            }

            Section(RenJistrolyStrings.text("settingsInteraction")) {
                Toggle(RenJistrolyStrings.text("settingsVoiceReply"), isOn: voiceOutputBinding)
                Toggle(RenJistrolyStrings.text("settingsContinuousVoice"), isOn: continuousVoiceBinding)

                HStack {
                    Text(RenJistrolyStrings.text("settingsGlobalHotkey"))
                    Spacer()
                    Text(RenJistrolyStrings.text("settingsHotkeyValue"))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }

                Picker(RenJistrolyStrings.text("settingsVoiceLanguage"), selection: .constant("zh-CN")) {
                    Text(RenJistrolyStrings.text("settingsChinese")).tag("zh-CN")
                    Text("English").tag("en-US")
                    Text(RenJistrolyStrings.text("settingsJapanese")).tag("ja-JP")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tool Safety

    private var toolSafetySettings: some View {
        Form {
            Section(RenJistrolyStrings.text("settingsToolAutoExecutePolicy")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(RenJistrolyStrings.text("settingsToolPolicyDescription"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Toggle(isOn: autoApproveLowBinding) {
                    VStack(alignment: .leading) {
                        Text(RenJistrolyStrings.text("settingsLowRiskAuto"))
                            .font(.system(size: 13, weight: .medium))
                        Text(RenJistrolyStrings.text("settingsLowRiskDesc"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: autoApproveMediumBinding) {
                    VStack(alignment: .leading) {
                        Text(RenJistrolyStrings.text("settingsMediumRiskAuto"))
                            .font(.system(size: 13, weight: .medium))
                        Text(RenJistrolyStrings.text("settingsMediumRiskDesc"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: autoApproveHighBinding) {
                    VStack(alignment: .leading) {
                        Text(RenJistrolyStrings.text("settingsHighRiskAuto"))
                            .font(.system(size: 13, weight: .medium))
                        Text(RenJistrolyStrings.text("settingsHighRiskDesc"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.red)
            }

            Section(RenJistrolyStrings.text("settingsPresets")) {
                HStack(spacing: 12) {
                    policyPresetButton(RenJistrolyStrings.text("settingsPresetDefault"), policy: .default, description: RenJistrolyStrings.text("settingsPresetDefaultDesc"))
                    policyPresetButton(RenJistrolyStrings.text("settingsPresetPermissive"), policy: .permissive, description: RenJistrolyStrings.text("settingsPresetPermissiveDesc"))
                    policyPresetButton(RenJistrolyStrings.text("settingsPresetStrict"), policy: .strict, description: RenJistrolyStrings.text("settingsPresetStrictDesc"))
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
            Section(RenJistrolyStrings.text("settingsAnthropic")) {
                SecureField(RenJistrolyStrings.text("settingsApiKeyPlaceholder"), text: $anthropicKey)
                    .onChange(of: anthropicKey) { _, newValue in
                        Task { await engine.configureCloudAPI(provider: .anthropic, key: newValue) }
                    }
                Text(RenJistrolyStrings.text("settingsGetApiKeyPrefix") + " console.anthropic.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("OpenAI") {
                SecureField(RenJistrolyStrings.text("settingsApiKeyPlaceholder"), text: $openAIKey)
                    .onChange(of: openAIKey) { _, newValue in
                        Task { await engine.configureCloudAPI(provider: .openAI, key: newValue) }
                    }
                Text(RenJistrolyStrings.text("settingsGetApiKeyPrefix") + " platform.openai.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("DeepSeek") {
                SecureField(RenJistrolyStrings.text("settingsApiKeyPlaceholder"), text: $deepseekKey)
                    .onChange(of: deepseekKey) { _, newValue in
                        Task { await engine.configureCloudAPI(provider: .deepseek, key: newValue) }
                    }
                Text(RenJistrolyStrings.text("settingsGetApiKeyPrefix") + " platform.deepseek.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(RenJistrolyStrings.text("settingsLocalMLX")) {
                HStack {
                    Text(RenJistrolyStrings.text("settingsMLXStatus"))
                    Spacer()
                    Text(RenJistrolyStrings.text("settingsMLXAvailable"))
                        .foregroundColor(.green)
                }
                Text(RenJistrolyStrings.text("settingsMLXDescription"))
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
            Section(RenJistrolyStrings.text("settingsDevMode")) {
                Toggle(RenJistrolyStrings.text("settingsEnableDevMode"), isOn: devModeBinding)

                if appState.devMode.isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(RenJistrolyStrings.text("settingsProjectPath"))
                            .font(.system(size: 12, weight: .medium))
                        HStack {
                            Text(appState.devMode.projectPath ?? contextCompilerPath)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Button(RenJistrolyStrings.text("settingsDetect")) {
                                appState.devMode.projectPath = engine.contextCompiler.currentContext?.rootPath
                            }
                            .font(.system(size: 11))
                        }
                    }
                }
            }

            if appState.devMode.isEnabled {
                Section(RenJistrolyStrings.text("settingsOCREngine")) {
                    Picker(RenJistrolyStrings.text("settingsOCREnginePicker"), selection: ocrEngineBinding) {
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
                            Text(engine.claudeCodeStatus.isInstalled ? RenJistrolyStrings.text("settingsClaudeCodeReady") : RenJistrolyStrings.text("settingsClaudeCodeNotDetected"))
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Button(RenJistrolyStrings.text("settingsClaudeCodeRefresh")) {
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
                            Text(RenJistrolyStrings.text("settingsCurrentProject"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(appState.devMode.projectPath ?? contextCompilerPath)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        TextField(RenJistrolyStrings.text("settingsClaudeCodePromptPlaceholder"), text: $claudeTaskPrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)

                        HStack {
                            Button(RenJistrolyStrings.text("settingsSavePath")) {
                                Task { await syncClaudeCodePath() }
                            }

                            Button(RenJistrolyStrings.text("settingsLaunchClaudeTask")) {
                                let prompt = claudeTaskPrompt
                                claudeTaskPrompt = ""
                                Task { await engine.launchClaudeCodeTask(prompt, appState: appState) }
                            }
                            .disabled(claudeTaskPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !engine.claudeCodeStatus.isInstalled)
                        }

                        Text(engine.claudeCodeStatus.isInstalled
                             ? RenJistrolyStrings.text("settingsClaudeCodeHelp")
                             : RenJistrolyStrings.text("settingsClaudeCodeNotInstalledHelp"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Section(RenJistrolyStrings.text("settingsQuickActions")) {
                    HStack {
                        Button {
                            Task {
                                let result = await engine.buildProject(appState: appState)
                                await engine.sendMessage(String(format: RenJistrolyStrings.text("settingsBuildResult"), result.summary), appState: appState)
                            }
                        } label: {
                            Label(RenJistrolyStrings.text("settingsBuild"), systemImage: "hammer")
                        }

                        Button {
                            Task {
                                let result = await engine.runTests(appState: appState)
                                await engine.sendMessage(String(format: RenJistrolyStrings.text("settingsTestResult"), result.summary), appState: appState)
                            }
                        } label: {
                            Label(RenJistrolyStrings.text("settingsTest"), systemImage: "checklist")
                        }
                    }

                    if let build = appState.devMode.lastBuildResult {
                        buildStatusRow(build)
                    }
                    if let test = appState.devMode.lastTestResult {
                        testStatusRow(test)
                    }
                }

                Section(RenJistrolyStrings.text("settingsSelfUpdate")) {
                    HStack {
                        Image(systemName: helperStatusIcon)
                            .foregroundColor(helperStatusColor)
                        Text(String(format: RenJistrolyStrings.text("settingsHelperLabel"), helperStatusText))
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Button(RenJistrolyStrings.text("settingsCheck")) {
                            Task { await updateManager?.checkHelperStatus() }
                        }
                        .font(.system(size: 11))
                    }

                    HStack {
                        Text(RenJistrolyStrings.text("settingsCurrentVersion"))
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
                            Label(RenJistrolyStrings.text("settingsInstallHelper"), systemImage: "gearshape.2")
                        }
                        .font(.system(size: 11))

                        Button {
                            Task {
                                let (ok, msg) = await updateManager?.verifySignature(
                                    of: Bundle.main.bundlePath
                                ) ?? (false, RenJistrolyStrings.text("settingsNoResponse"))
                                #if DEBUG
                                Logger.app.log("[SettingsView] 签名验证: \(ok ? "OK" : "FAIL", privacy: .public) — \(msg, privacy: .public)")
                                #endif
                            }
                        } label: {
                            Label(RenJistrolyStrings.text("settingsVerifySignature"), systemImage: "checkmark.seal")
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
        guard let status = updateManager?.helperStatus else { return RenJistrolyStrings.text("settingsHelperUnknown") }
        switch status {
        case .unknown: return RenJistrolyStrings.text("settingsHelperUnknown")
        case .notInstalled: return RenJistrolyStrings.text("settingsHelperNotInstalled")
        case .installed: return RenJistrolyStrings.text("settingsHelperInstalled")
        case .installing: return RenJistrolyStrings.text("settingsHelperInstalling")
        case .connected: return RenJistrolyStrings.text("settingsHelperConnected")
        case .error(let msg): return String(format: RenJistrolyStrings.text("settingsHelperError"), String(msg.prefix(30)))
        }
    }

    private var contextCompilerPath: String {
        engine.contextCompiler.currentContext?.rootPath ?? RenJistrolyStrings.text("settingsProjectNotDetected")
    }

    private func syncClaudeCodePath() async {
        await engine.setClaudeCodePath(claudeCodePath, appState: appState)
        claudeCodePath = engine.claudeCodeStatus.executablePath
    }

    private func buildStatusRow(_ result: BuildResult) -> some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            Text(String(format: RenJistrolyStrings.text("settingsRecentBuild"), result.summary))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func testStatusRow(_ result: TestResult) -> some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            Text(String(format: RenJistrolyStrings.text("settingsRecentTest"), result.summary))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Permissions

    private var permissionsSettings: some View {
        Form {
            Section {
                HStack {
                    Text(RenJistrolyStrings.text("settingsPermissionStatus"))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button {
                        Task { await refreshPermissions() }
                    } label: {
                        if isRefreshingPermissions {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Label(RenJistrolyStrings.text("settingsRefresh"), systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshingPermissions)
                }
            }

            Section(RenJistrolyStrings.text("settingsSystemPermissions")) {
                ForEach(SystemPermissionKind.allCases) { kind in
                    PermissionRow(
                        check: permissionChecks[kind] ?? SystemPermissionCheck(
                            kind: kind,
                            status: .unknown,
                            detail: RenJistrolyStrings.text("settingsNotRefreshed")
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

            Section(RenJistrolyStrings.text("settingsPrivacy")) {
                Text(RenJistrolyStrings.text("settingsPrivacyText"))
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

            Text(RenJistrolyStrings.text("settingsVersion") + " 0.1.0")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text(RenJistrolyStrings.text("settingsAboutTagline"))
                .font(.system(size: 16))

            Text(RenJistrolyStrings.text("settingsAboutDescription"))
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
                        Button(RenJistrolyStrings.text("settingsRequest")) {
                            requestAction()
                        }
                        .font(.system(size: 11))

                        Button(RenJistrolyStrings.text("settingsOpenSettings")) {
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
