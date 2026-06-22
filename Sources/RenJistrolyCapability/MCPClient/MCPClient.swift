import Foundation
import RenJistrolyModels

public actor MCPClient {
    public let registry: MCPToolRegistry
    public let safetyGateway: ToolSafetyGateway
    public let toolSkillRegistry: ToolSkillRegistry
    private var externalServers: [ExternalMCPServer] = []

    public init(
        registry: MCPToolRegistry = MCPToolRegistry(),
        toolSkillRegistry: ToolSkillRegistry = ToolSkillRegistry()
    ) {
        self.registry = registry
        self.toolSkillRegistry = toolSkillRegistry
        self.safetyGateway = ToolSafetyGateway(
            registry: registry,
            policyProvider: { .default }
        )
    }

    public func registerBuiltinTools() async {
        // Register built-in hooks
        await registry.registerHooks([
            VisualizerHook(),
        ])

        // Register built-in tools
        await registry.registerAll([
            // System control
            GetAppStateTool(),
            ListAppDriversTool(),
            OpenAppTool(),
            OpenURLTool(),
            OpenPathTool(),
            OpenInXcodeTool(),
            RevealInFinderTool(),
            XcodeNavigateTool(),
            ParseBuildErrorsTool(),
            ListSchemesTool(),
            BuildSettingsTool(),
            FinderSearchTool(),
            ListDirectoryTool(),
            GetFinderStateTool(),
            CreateFolderTool(),
            MoveFileTool(),
            CopyFileTool(),
            DeleteFileTool(),
            RenameFileTool(),
            BatchMoveTool(),
            BatchCopyTool(),
            BatchDeleteTool(),
            FileInfoTool(),
            SafariSearchTool(),
            GetBrowserStateTool(),
            TerminalRunTool(),
            SystemInfoTool(),
            RunningAppsTool(),
            ClickTool(),
            ClickElementTool(),
            ActivateMenuTool(),
            TypeTextTool(),
            SetValueTool(),
            ReadFocusedTextTool(),
            PressKeyTool(),
            ScrollTool(),
            WindowListTool(),
            FocusWindowTool(),
            DragTool(),
            UITreeTool(),
            DetectDialogsTool(),
            DialogPressButtonTool(),
            ListMenuItemsTool(),
            // Code tools
            GitStatusTool(),
            GitLogTool(),
            GitDiffTool(),
            ReadFileTool(),
            ListFilesTool(),
            FileEditTool(),
            WriteFileTool(),
            ShellCommandTool(),
            ClipboardTool(),
            ScreenshotCompareTool(),
            DOMInspectTool(),
            DOMClickTool(),
            DOMFillTool(),
            DOMSubmitTool(),
            // Developer tools
            SwiftBuildTool(),
            SwiftTestTool(),
            ProjectInfoTool(),
            RgSearchTool(),
            GitBlameTool(),
            GitBranchTool(),
            GitCommitTool(),
            GitStashTool(),
            GitPushPullTool(),
            GitRemoteTool(),
            GitResetTool(),
            GitMergeRebaseTool(),
            GitTagTool(),
            GitShowTool(),
            GitCherryPickTool(),
            GitRevertTool(),
            GitCleanTool(),
            ProcessTool(),
            XcodeBuildTool(),
            FindSymbolTool(),
            CodeSignTool(),
            ChangedFilesTool(),
            QuickOpenTool(),
            LSPTool(),
            // Engineer scenario tools (376-385)
            XcodeBuildAnalyzeTool(),
            TestAnalyzeTool(),
            RunTestsTool(),
            TestCoverageTool(),
            PrStatusTool(),
            CallChainTool(),
            ChangeScopeTool(),
            CIStatusTool(),
            CrashSymbolicateTool(),
            LockfileCheckTool(),
            EnvironmentDetectTool(),
            ProfileTool(),
            // Scenario tools
            PolishReplaceTool(),
            ExplainSelectedTool(),
            ReadScreenTool(),
            ScreenContextTool(),
            OCRTool(),
            // AppIntegration tools
            CloseWindowTool(),
            MinimizeWindowTool(),
            OpenFolderTool(),
            CopySelectedTool(),
            RightClickAtTool(),
            DoubleClickAtTool(),
            BrowserNavigateTool(),
            MediaControlTool(),
            OfficePasteTool(),
            OfficeSelectAllTool(),
            OfficeSaveTool(),
            OfficeUndoTool(),
            NotesPlannerTool(),
            MailPlannerTool(),
            CalendarPlannerTool(),
            // Business scenario tools (406-435)
            SessionContextTool(),
            ScriptStrategyTool(),
            HighRiskConfirmTool(),
            PermissionAwareTool(),
            SentimentAnalysisTool(),
            ContextIsolationTool(),
            TranslateWithToneTool(),
            CRMAuditTool(),
            RefundRiskTool(),
            OCRConfidenceCheckTool(),
            CRMFieldMappingTool(),
            SalesStageTool(),
            AmountChangeConfirmTool(),
            WebPageStructureTool(),
            BrowserFormTool(),
            TimezoneCheckTool(),
            QuoteTemplateTool(),
            ContractApprovalTool(),
            SpeakerDiarizationTool(),
            ReminderTool(),
            MultiWindowFusionTool(),
            ProductionSwitchTool(),
            DataExportMaskTool(),
            DryRunTool(),
            ChartOCRParseTool(),
            PushConfirmTool(),
            CSVValidateTool(),
            CMSVersionTool(),
            SiteConfirmTool(),
            WindowVerifyTool(),
            BaselineCompareTool(),
            // Developer workflow tools (436-440)
            CodeReviewTool(),
            GitWorkflowTool(),
            TerminalSessionTool(),
            BrowserDocTool(),
            ProjectDiagnoseTool(),
            // Designer scenario tools (386-395)
            FigmaInspectTool(),
            VisualCompareTool(),
            AssetNamingCheckTool(),
            PixelMeasureTool(),
            DesignSystemMapTool(),
            WindowSelectVerifyTool(),
            ScreenshotAnnotateTool(),
            KeynoteSafeEditTool(),
            DesignTokenMapTool(),
            UINodeReferenceTool(),
            // PM scenario tools (396-405)
            FeedbackCredibilityTool(),
            PRDGeneratorTool(),
            RequirementDecomposeTool(),
            ProgressTrackTool(),
            CompetitiveAnalysisTool(),
            MeetingNotesDecisionTool(),
            RoadmapConfidenceTool(),
            EmailConfirmRecipientTool(),
            IssueConfirmOperationTool(),
            ScreenPerceptionFallbackTool(),
            // Task management tools
            TaskCreateTool(),
            TaskListTool(),
            TaskUpdateTool(),
            TaskDeleteTool(),
            // Desktop management tools
            ClipboardHistoryTool(),
            WindowLayoutTool(),
            ScreenshotTool(),
            // System preferences tools
            DarkModeTool(),
            VolumeControlTool(),
            DisplayBrightnessTool(),
            NetworkInfoTool(),
            DoNotDisturbTool(),
            // Utility tools
            ArchiveTool(),
            HomebrewTool(),
            SpotlightSearchTool(),
            // Web search tools
            WebSearchTool(),
            WebFetchTool(),
            // CDP Chrome DevTools Protocol tools
            CDPConnectTool(),
            CDPDisconnectTool(),
            CDPStatusTool(),
            CDPEvaluateTool(),
            CDPNavigateTool(),
            CDPCaptureScreenshotTool(),
            CDPGetCookiesTool(),
            CDPSetCookieTool(),
            CDPBlockURLsTool(),
            CDPEnableNetworkTool(),
            CDPEnableConsoleTool(),
            CDPGetDocumentTool(),
            CDPQuerySelectorTool(),
            CDPQuerySelectorAllTool(),
            CDPClickTool(),
            CDPFillTool(),
            CDPSubmitTool(),
            CDPGetOuterHTMLTool(),
            CDPGetAttributesTool(),
            CDPGetPerformanceTool(),
            CDPReloadTool(),
            CDPListTabsTool(),
            CDPNewTabTool(),
            CDPCloseTabTool(),
            CDPActivateTabTool(),
            CDPPrintToPDFTool(),
            CDPGetNetworkEntriesTool(),
            CDPGetConsoleMessagesTool(),
        ])
    }

    public var availableTools: [ToolDefinition] {
        get async { await registry.allDefinitions }
    }

    /// Get tool definitions filtered by skill. When no skills provided,
    /// returns all tools. When "general" skill is included, returns all tools.
    public func tools(for skills: [Skill]) async -> [ToolDefinition] {
        let all = await registry.allDefinitions
        return await toolSkillRegistry.toolDefinitions(for: skills, from: all)
    }

    /// Get tools matched to the domains of a RoutedTask.
    public func tools(for task: RoutedTask) async -> [ToolDefinition] {
        let domain = SkillDomain.from(taskKind: task.primaryRoute.kind)
        let matched = await toolSkillRegistry.skills(for: [domain])
        return await tools(for: matched)
    }

    /// Get tools matched to a prompt via keyword routing.
    public func tools(matching prompt: String) async -> [ToolDefinition] {
        let matched = await toolSkillRegistry.match(prompt)
        return await tools(for: matched)
    }

    /// Compile skill-based system prompts for a task.
    public func skillPrompt(for task: RoutedTask) async -> String {
        let domain = SkillDomain.from(taskKind: task.primaryRoute.kind)
        let matched = await toolSkillRegistry.skills(for: [domain])
        return await toolSkillRegistry.compileSystemPrompt(for: matched)
    }

    public func execute(_ request: ToolCallRequest) async throws -> ToolCallResult {
        try await execute(request, policy: .default)
    }

    public func execute(_ request: ToolCallRequest, policy: ToolExecutionPolicy) async throws -> ToolCallResult {
        if let blocked = await safetyGateway.blockedResult(for: request) {
            return blocked
        }
        let assessment = await assessRisk(request)
        guard policy.canAutoExecute(assessment.riskLevel) else {
            throw ToolNeedsConfirmationError(assessment: assessment, request: request)
        }
        return try await registry.executeTool(request)
    }

    /// Execute an already-assessed tool after user confirmation. Only for
    /// confirmation flows that have done `assessRisk` + `requestConfirmation`.
    public func executePreAssessed(_ request: ToolCallRequest) async throws -> ToolCallResult {
        if let blocked = await safetyGateway.blockedResult(for: request) {
            return blocked
        }
        return try await registry.executeTool(request)
    }

    /// Internal read-only queries that must be low risk. Throws if the
    /// tool is medium/high risk — use `execute(_:policy:)` for those.
    public func executeLowRisk(_ request: ToolCallRequest) async throws -> ToolCallResult {
        if let blocked = await safetyGateway.blockedResult(for: request) {
            return blocked
        }
        let assessment = await assessRisk(request)
        guard assessment.riskLevel <= .low else {
            throw ToolNeedsConfirmationError(assessment: assessment, request: request)
        }
        return try await registry.executeTool(request)
    }

    public func assessRisk(_ request: ToolCallRequest) async -> ToolRiskAssessment {
        await safetyGateway.assess(request)
    }

    public func executeAll(_ requests: [ToolCallRequest]) async -> [ToolCallResult] {
        var results: [ToolCallResult] = []
        for request in requests {
            if let blocked = await safetyGateway.blockedResult(for: request) {
                results.append(blocked)
                continue
            }
            if let result = try? await registry.executeTool(request) {
                results.append(result)
            } else {
                results.append(ToolCallResult(
                    id: request.id,
                    output: "执行失败",
                    isError: true
                ))
            }
        }
        return results
    }

    public func connectExternalServer(config: ExternalMCPServer.Config) async throws {
        let server = ExternalMCPServer(config: config)
        externalServers.append(server)
    }

    public func disconnectExternalServer(id: String) {
        externalServers.removeAll { $0.id == id }
    }
}

public struct ExternalMCPServer: Identifiable, Sendable {
    public let id: String
    public let config: Config

    public init(config: Config) {
        self.id = UUID().uuidString
        self.config = config
    }
}

extension ExternalMCPServer {
    public struct Config: Sendable, Hashable {
        public let name: String
        public let command: String
        public let args: [String]
        public let env: [String: String]?

        public init(name: String, command: String, args: [String] = [], env: [String: String]? = nil) {
            self.name = name
            self.command = command
            self.args = args
            self.env = env
        }
    }
}
