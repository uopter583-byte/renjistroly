import Foundation

public struct Skill: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let description: String
    public let domain: SkillDomain
    public let toolNames: [String]
    public let triggerKeywords: [String]
    public let systemPrompt: String

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        domain: SkillDomain,
        toolNames: [String],
        triggerKeywords: [String] = [],
        systemPrompt: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.domain = domain
        self.toolNames = toolNames
        self.triggerKeywords = triggerKeywords
        self.systemPrompt = systemPrompt
    }

    public static func builtinSkills() -> [Skill] {
        [
            .systemControl,
            .code,
            .browser,
            .fileSystem,
            .business,
            .designer,
            .pm,
            .utility,
            .general,
        ]
    }
}

public enum SkillDomain: String, Codable, Sendable, Hashable, CaseIterable {
    case systemControl = "system_control"
    case code
    case browser
    case fileSystem = "file_system"
    case business
    case designer
    case pm
    case utility
    case general
}

extension SkillDomain {
    public static func from(taskKind: TaskKind) -> SkillDomain {
        switch taskKind {
        case .code: return .code
        case .desktop: return .systemControl
        case .browser: return .browser
        case .fileSystem: return .fileSystem
        case .chat, .mixed: return .general
        }
    }

    public var displayName: String {
        switch self {
        case .systemControl: return "系统控制"
        case .code: return "代码开发"
        case .browser: return "浏览器/网络"
        case .fileSystem: return "文件系统"
        case .business: return "业务场景"
        case .designer: return "设计师"
        case .pm: return "产品经理"
        case .utility: return "实用工具"
        case .general: return "通用"
        }
    }
}

// MARK: - Built-in Skill Definitions

extension Skill {
    static let systemControl = Skill(
        name: "system_control",
        description: "macOS 桌面操控：点击、输入、滚动、拖拽、打开应用、菜单操作",
        domain: .systemControl,
        toolNames: [
            "get_app_state", "list_app_drivers", "open_app", "open_url", "open_path",
            "open_in_xcode", "reveal_in_finder", "click", "click_element",
            "type_text", "set_value", "press_key", "scroll", "drag",
            "activate_menu", "list_menu_items", "close_window", "minimize_window",
            "focus_window", "list_windows", "get_ui_tree", "right_click_at",
            "double_click_at", "window_layout", "screenshot",
            "detect_dialogs", "dialog_press_button",
            "finder_search", "list_directory", "get_finder_state",
            "open_folder", "xcode_navigate",
        ],
        triggerKeywords: ["点击", "输入", "打开", "滚动", "拖拽", "桌面", "窗口", "菜单",
                          "click", "type", "scroll", "drag", "open", "app"],
        systemPrompt: """
        你正在执行 macOS 桌面控制操作。使用系统控制工具进行 GUI 自动化。
        在点击或输入前，先使用 get_app_state 或 get_ui_tree 了解当前界面状态。
        """
    )

    static let code = Skill(
        name: "code",
        description: "代码开发与版本控制：Git 操作、构建、测试、代码编辑",
        domain: .code,
        toolNames: [
            "git_status", "git_log", "git_diff", "git_blame", "git_branch",
            "git_commit", "git_stash", "git_push_pull", "git_remote",
            "git_reset", "git_merge_rebase", "git_tag", "git_show",
            "git_cherry_pick", "git_revert", "git_clean",
            "swift_build", "swift_test", "test_analyze", "run_tests",
            "test_coverage", "xcode_build", "xcode_build_analyze",
            "build_settings", "list_schemes",
            "shell_command", "terminal_run",
            "read_file", "write_file", "file_edit", "list_files",
            "rg_search", "quick_open", "find_symbol", "lsp_symbol",
            "pr_status", "call_chain", "change_scope",
            "code_sign_info", "crash_symbolicate", "lockfile_check",
            "project_info", "project_diagnose",
            "ci_status", "profile_collect",
            "changed_files", "environment_detect",
            "code_review", "archive",
        ],
        triggerKeywords: ["代码", "开发", "构建", "测试", "Git", "提交", "分支",
                          "code", "build", "test", "git", "commit", "branch",
                          "重构", "实现", "修复", "调试", "编译"],
        systemPrompt: """
        你正在执行代码开发任务。使用 Git、构建和代码编辑工具。
        对于多文件修改，先使用 read_file 了解现有代码，再进行编辑。
        修改后务必运行 swift build 确保编译通过，运行相关测试确保功能正常。
        """
    )

    static let browser = Skill(
        name: "browser",
        description: "浏览器自动化与网页搜索：Safari/Chrome 控制、网页内容获取",
        domain: .browser,
        toolNames: [
            "safari_search", "get_browser_state", "browser_navigate",
            "dom_inspect", "dom_click", "dom_fill", "dom_submit",
            "web_search", "web_fetch",
            "webpage_structure", "browser_form", "site_confirm",
            "cdp_connect", "cdp_disconnect", "cdp_status",
            "cdp_evaluate", "cdp_navigate", "cdp_capture_screenshot",
            "cdp_get_cookies", "cdp_set_cookie", "cdp_block_urls",
            "cdp_enable_network", "cdp_enable_console",
            "cdp_get_document", "cdp_query_selector",
        ],
        triggerKeywords: ["浏览器", "搜索", "网页", "URL", "Safari", "Chrome",
                          "browser", "search", "web", "page", "网站", "网络"],
        systemPrompt: """
        你正在执行浏览器操作或网络搜索。使用浏览器工具进行网页自动化和信息检索。
        先使用 get_browser_state 了解当前页面状态，再进行操作。
        """
    )

    static let fileSystem = Skill(
        name: "file_system",
        description: "文件系统操作：创建、移动、复制、删除文件和目录",
        domain: .fileSystem,
        toolNames: [
            "list_directory", "list_files", "read_file", "write_file",
            "file_edit", "file_info", "finder_search",
            "create_folder", "move_file", "copy_file", "delete_file",
            "rename_file", "batch_move", "batch_copy", "batch_delete",
            "archive", "spotlight_search",
        ],
        triggerKeywords: ["文件", "目录", "文件夹", "移动", "复制", "删除", "创建",
                          "file", "directory", "folder", "move", "copy", "delete"],
        systemPrompt: """
        你正在执行文件系统操作。修改文件前先使用 read_file 查看内容。
        批量操作时使用 batch_* 工具确保一致性。
        """
    )

    static let business = Skill(
        name: "business",
        description: "业务场景：CRM、销售、客服、合同、权限管理",
        domain: .business,
        toolNames: [
            "session_context", "script_strategy", "high_risk_confirm",
            "permission_aware", "sentiment_analysis", "context_isolation",
            "translate_with_tone", "crm_audit", "crm_field_mapping",
            "refund_risk_assess", "ocr_confidence_check",
            "sales_stage", "amount_change_confirm",
            "timezone_check", "quote_template", "contract_approval",
            "speaker_diarization", "reminder",
            "multi_window_fusion", "production_switch",
            "data_export_mask", "dry_run", "chart_ocr_parse",
            "push_confirm", "csv_validate", "cms_version",
            "site_confirm", "window_verify", "baseline_compare",
            "email_confirm_recipient", "issue_confirm_operation",
        ],
        triggerKeywords: ["客户", "销售", "CRM", "合同", "报价", "客服",
                          "customer", "sales", "contract", "quote",
                          "审批", "approval", "退款"],
        systemPrompt: """
        你正在执行业务操作。涉及金额修改、合同审批、发送消息等操作时，
        先确认客户信息和当前阶段，使用对应的业务工具完成操作。
        """
    )

    static let designer = Skill(
        name: "designer",
        description: "设计师工具：Figma 检查、视觉对比、设计系统、截图标注",
        domain: .designer,
        toolNames: [
            "figma_inspect", "visual_compare", "asset_naming_check",
            "pixel_measure", "design_system_map", "window_select_verify",
            "screenshot_annotate", "keynote_safe_edit",
            "design_token_map", "ui_node_reference",
        ],
        triggerKeywords: ["设计", "Figma", "像素", "设计系统", "标注",
                          "design", "figma", "pixel", "visual"],
        systemPrompt: """
        你正在执行设计相关操作。使用截图和测量工具辅助设计评审。
        """
    )

    static let pm = Skill(
        name: "pm",
        description: "产品经理工具：PRD、需求拆解、竞品分析、会议记录",
        domain: .pm,
        toolNames: [
            "feedback_credibility", "prd_generator", "requirement_decompose",
            "progress_track", "competitive_analysis",
            "meeting_notes_decision", "roadmap_confidence",
            "email_confirm_recipient", "issue_confirm_operation",
        ],
        triggerKeywords: ["PRD", "需求", "产品", "路线图", "竞品分析",
                          "prd", "requirement", "product", "roadmap",
                          "会议", "meeting", "反馈"],
        systemPrompt: """
        你正在执行产品经理相关操作。使用分析工具辅助决策。
        """
    )

    static let utility = Skill(
        name: "utility",
        description: "实用工具：剪贴板、系统设置、网络信息、系统信息",
        domain: .utility,
        toolNames: [
            "clipboard", "clipboard_history", "screenshot",
            "screenshot_compare", "dark_mode", "volume_control",
            "display_brightness", "network_info", "do_not_disturb",
            "system_info", "running_apps", "process",
            "archive", "homebrew", "spotlight_search",
            "copy_selected", "office_paste", "office_select_all",
            "office_save", "office_undo",
            "media_control",
        ],
        triggerKeywords: ["剪贴板", "系统设置", "音量", "亮度", "网络",
                          "clipboard", "settings", "volume", "brightness"],
        systemPrompt: """
        你正在执行系统实用操作。使用相应的工具完成设置和实用功能。
        """
    )

    static let general = Skill(
        name: "general",
        description: "通用能力：所有的基础辅助工具",
        domain: .general,
        toolNames: [], // 空 = 所有工具
        triggerKeywords: [],
        systemPrompt: "你是一个通用的 macOS AI 助手，可以使用所有可用工具来帮助用户完成任务。"
    )
}
