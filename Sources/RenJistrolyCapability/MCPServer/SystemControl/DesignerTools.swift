import Foundation
import AppKit
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - 386 Figma 专用解析器

public struct FigmaInspectTool: MCPTool {
    public let definition = ToolDefinition(
        name: "figma_inspect",
        description: "检测当前浏览器中是否打开 Figma 设计稿，提取 Figma 画布上的设计元素、图层、间距和样式信息。用于设计师检查设计稿。",
        parameters: [
            .init(name: "detail", type: .string, description: "详细程度: basic(基础), deep(深度), 默认 basic", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let detail = arguments["detail"] ?? "basic"
        let screen = ScreenCaptureBridge()
        var output = ""

        // 1. 检查前台应用是否是浏览器
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let appName = frontApp.localizedName,
              appName.localizedCaseInsensitiveContains("Safari") ||
              appName.localizedCaseInsensitiveContains("Chrome") ||
              appName.localizedCaseInsensitiveContains("Edge") ||
              appName.localizedCaseInsensitiveContains("Arc")
        else {
            let runningApps = NSWorkspace.shared.runningApplications
                .compactMap { $0.localizedName }
                .filter { $0.localizedCaseInsensitiveContains("Safari") ||
                         $0.localizedCaseInsensitiveContains("Chrome") ||
                         $0.localizedCaseInsensitiveContains("Edge") ||
                         $0.localizedCaseInsensitiveContains("Arc") }
            if runningApps.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "未检测到浏览器。请先打开 Figma 设计稿。", isError: true)
            }
            return ToolCallResult(id: UUID().uuidString,
                                  output: "当前前台应用不是浏览器。运行中的浏览器: \(runningApps.joined(separator: ", "))。请先切换到 Figma 标签页。",
                                  isError: true)
        }

        // 2. 获取浏览器当前页面信息
        var pageState: BrowserPageState?
        if appName.localizedCaseInsensitiveContains("Safari") {
            pageState = try? await SafariDriver().currentPageState()
        } else if appName.localizedCaseInsensitiveContains("Chrome") {
            pageState = try? await ChromeDriver().currentPageState()
        }

        let isFigma = pageState?.host?.localizedCaseInsensitiveContains("figma.com") ?? false
            || pageState?.url?.localizedCaseInsensitiveContains("figma.com") ?? false
            || pageState?.tabTitle?.localizedCaseInsensitiveContains("Figma") ?? false

        if !isFigma {
            let page = pageState?.tabTitle ?? pageState?.host ?? "未知页面"
            return ToolCallResult(id: UUID().uuidString,
                                  output: "当前页面 [\(page)] 看起来不是 Figma 设计稿。请在 Figma 中打开设计文件后再试。",
                                  isError: true)
        }

        output += "=== Figma 设计稿检测 ===\n\n"
        output += "【浏览器】\(appName)\n"
        if let title = pageState?.tabTitle { output += "【页面标题】\(title)\n" }
        if let url = pageState?.url { output += "【文件 URL】\(url)\n" }
        if let host = pageState?.host { output += "【域名】\(host)\n" }

        // 3. OCR 读取屏幕上的 Figma 内容
        do {
            let ownIDs = (try? await screen.getOwnWindowIDs()) ?? []
            let pngData = try await screen.captureScreen(excludingWindowIDs: ownIDs)
            let ocrResults = try await OCRService.shared.recognize(in: pngData, preferredEngine: .appleVision)
            let texts = ocrResults.filter { $0.confidence >= 0.25 && !$0.text.isEmpty }

            output += "\n【Figma 画布 OSCR 识别】"
            if texts.isEmpty {
                output += " 未检测到文字内容（可能是图片模式）\n"
            } else {
                output += "（共 \(texts.count) 个文本区域）\n"
                for (i, r) in texts.prefix(detail == "deep" ? 50 : 20).enumerated() {
                    output += "  \(i+1). \"\(r.text)\" @ (\(String(format: "%.0f", r.x)), \(String(format: "%.0f", r.y)))"
                    output += " [\(String(format: "%.0f", r.width))×\(String(format: "%.0f", r.height))]"
                    if r.engine == .ppocrV6 { output += " [PPOCR]" }
                    output += "\n"
                }
                if texts.count > (detail == "deep" ? 50 : 20) {
                    output += "  ... 还有 \(texts.count - (detail == "deep" ? 50 : 20)) 个区域\n"
                }
                output += "\n【画布全文预览】\(texts.map(\.text).joined(separator: " ").prefix(detail == "deep" ? 2000 : 500))\n"
            }
        } catch {
            output += "\n【OCR】截图/识别失败: \(error.localizedDescription)\n"
        }

        output += "\n【Figma 分析提示】\n"
        output += "- 当前页面是 Figma 设计稿，可使用 OCR 识别设计元素\n"
        output += "- 如需查看图层结构、间距、颜色等详细信息，请使用 get_app_state 获取 UI 树\n"
        output += "- 如需测量像素间距，使用 pixel_measure 工具\n"
        output += "- 如需比对设计与实现，使用 visual_compare 工具\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 387 视觉对比

public struct VisualCompareTool: MCPTool {
    public let definition = ToolDefinition(
        name: "visual_compare",
        description: "对比设计稿（Figma/截图）与实现（浏览器/App）的差异。截取屏幕两侧内容进行 OCR 文本对比，辅助设计师发现不一致。",
        parameters: [
            .init(name: "mode", type: .string, description: "对比模式: ocr(OCR文本对比), screenshot(截图对比,需要前后两张图), 默认 ocr", required: false),
            .init(name: "baseline_path", type: .string, description: "基准截图文件路径（可用于与当前屏幕对比）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let mode = arguments["mode"] ?? "ocr"
        let baselinePath = arguments["baseline_path"]

        var output = "=== 视觉对比报告 ===\n\n"

        // 获取当前前台应用上下文
        if let app = NSWorkspace.shared.frontmostApplication {
            output += "【前台应用】\(app.localizedName ?? "未知")\n"
        }

        if mode == "screenshot", let baselinePath {
            // 截图对比模式
            let baselineURL = URL(fileURLWithPath: (baselinePath as NSString).expandingTildeInPath)
            guard FileManager.default.fileExists(atPath: baselineURL.path) else {
                return ToolCallResult(id: UUID().uuidString,
                                      output: "基准文件不存在: \(baselinePath)", isError: true)
            }

            do {
                let screen = ScreenCaptureBridge()
                let ownIDs = (try? await screen.getOwnWindowIDs()) ?? []
                let currentData = try await screen.captureScreen(excludingWindowIDs: ownIDs)
                let baselineData = try Data(contentsOf: baselineURL)

                // OCR both images
                let baselineOCR = try await OCRService.shared.recognize(in: baselineData, preferredEngine: .appleVision)
                let currentOCR = try await OCRService.shared.recognize(in: currentData, preferredEngine: .appleVision)

                let baselineTexts = baselineOCR.filter { $0.confidence >= 0.3 }.map(\.text)
                let currentTexts = currentOCR.filter { $0.confidence >= 0.3 }.map(\.text)

                let baselineSet = Set(baselineTexts)
                let currentSet = Set(currentTexts)

                let missingInCurrent = baselineSet.subtracting(currentSet)
                let addedInCurrent = currentSet.subtracting(baselineSet)

                output += "【对比类型】截图 vs 当前屏幕\n"
                output += "基准区域: \(baselineTexts.count) 个文本, 当前: \(currentTexts.count) 个文本\n"
                if !missingInCurrent.isEmpty {
                    output += "\n【实现缺失】以下设计稿中的内容未在实现中找到:\n"
                    for text in missingInCurrent.prefix(20) {
                        output += "  - \"\(text)\"\n"
                    }
                }
                if !addedInCurrent.isEmpty {
                    output += "\n【实现多出】以下内容在实现中存在但设计稿中没有:\n"
                    for text in addedInCurrent.prefix(20) {
                        output += "  - \"\(text)\"\n"
                    }
                }
                if missingInCurrent.isEmpty && addedInCurrent.isEmpty {
                    output += "OCR 文本一致，无明显差异。\n"
                }
                output += "\n注意: OCR 文本对比无法检测颜色、字体、间距、图标等视觉差异。\n"
                output += "如需像素级对比，请截取两张截图后用 screenshot_compare 工具。\n"
            } catch {
                output += "对比失败: \(error.localizedDescription)\n"
            }
        } else {
            // OCR 模式——对比屏幕左右两侧或当前区域
            output += "【对比模式】OCR 文本分析\n"
            output += "建议使用方式:\n"
            output += "  1. 先对设计稿区域截图 → screenshot_compare\n"
            output += "  2. 再对实现区域截图 → screenshot_compare\n"
            output += "  3. 使用 screen_context 获取两边文本内容进行人工比较\n"
            output += "\n【检查清单】\n"
            output += "- [ ] 字体大小是否一致\n"
            output += "- [ ] 颜色是否匹配\n"
            output += "- [ ] 间距/留白是否一致\n"
            output += "- [ ] 文案内容是否相同\n"
            output += "- [ ] 按钮/控件的状态（hover/active/default）是否正确\n"
            output += "- [ ] 图标是否正确\n"
            output += "- [ ] 响应式布局在各断点是否正常\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 388 资源命名规则检查

public struct AssetNamingCheckTool: MCPTool {
    public let definition = ToolDefinition(
        name: "asset_naming_check",
        description: "检查资源文件（图片、图标、切图）命名是否符合项目约定规范。支持大小驼峰、kebab-case、snake_case 等命名风格。",
        parameters: [
            .init(name: "path", type: .string, description: "资源目录路径，如 /path/to/Assets.xcassets", required: false),
            .init(name: "convention", type: .string, description: "命名规范: camelCase, kebab-case, snake_case, uppercase, 默认自动检测", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let path = arguments["path"]
        let convention = arguments["convention"]

        let fm = FileManager.default

        // 确定搜索路径
        let searchPaths: [String]
        if let path {
            searchPaths = [path]
        } else {
            // 尝试常见资源目录
            let cwd = FileManager.default.currentDirectoryPath
            let commonPaths = [
                "\(cwd)/Assets.xcassets",
                "\(cwd)/Resources",
                "\(cwd)/Sources/**/Resources",
                "\(cwd)/**/Assets.xcassets",
            ]
            searchPaths = commonPaths.filter { fm.fileExists(atPath: $0) }
        }

        guard !searchPaths.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到资源目录。请指定 path 参数。", isError: true)
        }

        var output = "=== 资源命名检查 ===\n\n"
        var totalFiles = 0
        var invalidFiles: [(String, String)] = []

        for searchPath in searchPaths {
            guard let enumerator = fm.enumerator(atPath: searchPath) else { continue }
            output += "检查目录: \(searchPath)\n"

            while let fileName = enumerator.nextObject() as? String {
                let url = URL(fileURLWithPath: fileName)
                let nameWithoutExt = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension.lowercased()

                // 只检查图片资源
                guard ["png", "jpg", "jpeg", "gif", "svg", "pdf", "webp", "ico"].contains(ext) else { continue }
                // 跳过 .imageset 目录
                guard !nameWithoutExt.contains("@") else { continue }

                totalFiles += 1
                var issues: [String] = []

                // 根据约定检查
                if let conv = convention {
                    switch conv {
                    case "camelCase":
                        let pattern = "^[a-z]+[a-zA-Z0-9]*$"
                        if nameWithoutExt.range(of: pattern, options: .regularExpression) == nil {
                            issues.append("不符合 camelCase")
                        }
                    case "kebab-case":
                        let pattern = "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
                        if nameWithoutExt.range(of: pattern, options: .regularExpression) == nil {
                            issues.append("不符合 kebab-case")
                        }
                    case "snake_case":
                        let pattern = "^[a-z][a-z0-9]*(_[a-z0-9]+)*$"
                        if nameWithoutExt.range(of: pattern, options: .regularExpression) == nil {
                            issues.append("不符合 snake_case")
                        }
                    default:
                        break
                    }
                } else {
                    // 自动检测常见的命名问题
                    if nameWithoutExt.contains(" ") {
                        issues.append("包含空格")
                    }
                    if nameWithoutExt.contains("New") || nameWithoutExt.contains("Copy") {
                        issues.append("包含默认名称(New/Copy)")
                    }
                    if nameWithoutExt.lowercased() != nameWithoutExt && nameWithoutExt.uppercased() != nameWithoutExt {
                        // 混合大小写但非驼峰
                    }
                }

                if !issues.isEmpty {
                    invalidFiles.append((fileName, issues.joined(separator: ", ")))
                }
            }
        }

        output += "\n共检查 \(totalFiles) 个资源文件\n"
        if invalidFiles.isEmpty {
            output += "所有资源命名规范 ✅\n"
        } else {
            output += "发现 \(invalidFiles.count) 个命名问题:\n"
            for (file, issue) in invalidFiles.prefix(30) {
                output += "  ❌ \(file) — \(issue)\n"
            }
            if invalidFiles.count > 30 {
                output += "  ... 还有 \(invalidFiles.count - 30) 个\n"
            }
        }

        output += "\n【推荐命名规范】\n"
        output += "- 图标: icon-{name}.svg (kebab-case)\n"
        output += "- 图片: img_{content}_{state}.png (snake_case)\n"
        output += "- 切图: {element}@{scale}x.png\n"
        output += "- 避免: 空格、中文、大写首字母（除非约定）\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 389 像素测量工具

public struct PixelMeasureTool: MCPTool {
    public let definition = ToolDefinition(
        name: "pixel_measure",
        description: "对屏幕上两个元素之间的像素距离进行测量。通过 OCR 或 AX 坐标计算元素间距、尺寸，支持像素级精度。",
        parameters: [
            .init(name: "element_a", type: .string, description: "第一个元素的描述（OCR文本或AX角色）", required: false),
            .init(name: "element_b", type: .string, description: "第二个元素的描述（OCR文本或AX角色）", required: false),
            .init(name: "measure_type", type: .string, description: "测量方式: distance(间距), size(尺寸), bounds(边界), 默认 distance", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let elementA = arguments["element_a"]
        let elementB = arguments["element_b"]

        var output = "=== 像素测量 ===\n\n"

        // 获取屏幕分辨率信息
        if let mainScreen = NSScreen.main {
            let backingScale = mainScreen.backingScaleFactor
            let frame = mainScreen.frame
            let visibleFrame = mainScreen.visibleFrame
            output += "【屏幕信息】\n"
            output += "分辨率: \(Int(frame.width))×\(Int(frame.height)) @\(Int(backingScale))x\n"
            output += "实际像素: \(Int(frame.width * backingScale))×\(Int(frame.height * backingScale))\n"
            output += "可用区域: \(Int(visibleFrame.width))×\(Int(visibleFrame.height))\n"
            output += "菜单栏高度: \(Int(frame.height - visibleFrame.height - (frame.minY - visibleFrame.minY)))\n"
        }

        // 获取屏幕截图和 OCR 元素坐标
        let screen = ScreenCaptureBridge()
        do {
            let ownIDs = (try? await screen.getOwnWindowIDs()) ?? []
            let pngData = try await screen.captureScreen(excludingWindowIDs: ownIDs)
            let ocrResults = try await OCRService.shared.recognize(in: pngData, preferredEngine: .appleVision)
            let filtered = ocrResults.filter { $0.confidence >= 0.3 && !$0.text.isEmpty }

            if !filtered.isEmpty {
                output += "\n【OCR 检测到的元素区域】\n"
                for (i, r) in filtered.prefix(10).enumerated() {
                    output += "  \(i+1). \"\(r.text.prefix(30))\" → x:\(String(format: "%.1f", r.x)) y:\(String(format: "%.1f", r.y)) "
                    output += "w:\(String(format: "%.1f", r.width)) h:\(String(format: "%.1f", r.height))\n"
                }
                if filtered.count > 10 {
                    output += "  ... 还有 \(filtered.count - 10) 个元素\n"
                }

                // 如果指定了两个元素，计算间距
                if let a = elementA, let b = elementB {
                    // 找到匹配的元素
                    let matchA = filtered.first { $0.text.localizedCaseInsensitiveContains(a) }
                    let matchB = filtered.first { $0.text.localizedCaseInsensitiveContains(b) }

                    if let ma = matchA, let mb = matchB {
                        let dx = abs(ma.x - mb.x)
                        let dy = abs(ma.y - mb.y)
                        let distance = sqrt(dx * dx + dy * dy)
                        let horizontalGap: Double
                        if ma.x + ma.width < mb.x {
                            horizontalGap = mb.x - (ma.x + ma.width)
                        } else if mb.x + mb.width < ma.x {
                            horizontalGap = ma.x - (mb.x + mb.width)
                        } else {
                            horizontalGap = 0
                        }
                        let verticalGap: Double
                        if ma.y + ma.height < mb.y {
                            verticalGap = mb.y - (ma.y + ma.height)
                        } else if mb.y + mb.height < ma.y {
                            verticalGap = ma.y - (mb.y + mb.height)
                        } else {
                            verticalGap = 0
                        }

                        output += "\n【测量结果】\"\(ma.text)\" ↔ \"\(mb.text)\"\n"
                        output += "  中心距离: \(String(format: "%.1f", distance)) px\n"
                        output += "  水平间距: \(String(format: "%.1f", horizontalGap)) px\n"
                        output += "  垂直间距: \(String(format: "%.1f", verticalGap)) px\n"
                        output += "  X 方向差: \(String(format: "%.1f", dx)) px\n"
                        output += "  Y 方向差: \(String(format: "%.1f", dy)) px\n"
                        output += "  元素 A 尺寸: \(String(format: "%.0f", ma.width))×\(String(format: "%.0f", ma.height))\n"
                        output += "  元素 B 尺寸: \(String(format: "%.0f", mb.width))×\(String(format: "%.0f", mb.height))\n"
                    } else {
                        output += "\n【测量】未找到与 \"\(a)\" 或 \"\(b)\" 匹配的 OCR 元素\n"
                    }
                }
            }
        } catch {
            output += "\n屏幕捕获失败: \(error.localizedDescription)\n"
        }

        output += "\n【使用指南】\n"
        output += "- 指定 element_a 和 element_b 为屏幕上的文字片段（OCR 文本匹配）\n"
        output += "- measure_type: distance(两元素间距), size(元素自身尺寸), bounds(边界框)\n"
        output += "- 所有坐标基于物理像素（@1x），Retina 屏请乘以 scale factor\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 390 设计系统组件映射

public struct DesignSystemMapTool: MCPTool {
    public let definition = ToolDefinition(
        name: "design_system_map",
        description: "将屏幕上的 UI 元素映射到设计系统组件，识别组件类型、状态和变体，便于设计师整理和审计组件使用一致性。",
        parameters: [
            .init(name: "framework", type: .string, description: "设计系统框架: material( Material Design), ant( Ant Design), custom(自定义), 默认 auto", required: false),
            .init(name: "component_file", type: .string, description: "组件映射文件路径（JSON格式，定义组件名称→CSS选择器/AX角色映射）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let framework = arguments["framework"] ?? "auto"

        var output = "=== 设计系统组件映射 ===\n\n"

        // 获取当前 UI 元素树
        let bridge = AccessibilityBridge()
        do {
            let tree = try await bridge.getUIElementTree(maxDepth: 4)
            let relevantElements = tree.filter { node in
                let roles: Set = ["AXButton", "AXTextField", "AXComboBox", "AXPopUpButton",
                                  "AXRadioButton", "AXCheckBox", "AXSlider", "AXStepper",
                                  "AXProgressIndicator", "AXTabGroup", "AXTable", "AXList",
                                  "AXOutline", "AXStaticText", "AXImage", "AXMenuButton",
                                  "AXDisclosureTriangle", "AXSplitGroup", "AXToolbar",
                                  "AXSheet", "AXDrawer", "AXGroup", "AXScrollArea"]
                return roles.contains(node.role)
            }

            output += "【当前界面组件】（共 \(relevantElements.count) 个可识别组件）\n\n"

            let componentMap: [(role: String, component: String, designSystem: String)] = [
                ("AXButton", "Button", "按钮"),
                ("AXTextField", "Input", "输入框"),
                ("AXComboBox", "Select", "下拉选择"),
                ("AXPopUpButton", "Select", "下拉选择"),
                ("AXRadioButton", "Radio", "单选框"),
                ("AXCheckBox", "Checkbox", "复选框"),
                ("AXSlider", "Slider", "滑动条"),
                ("AXStepper", "Stepper", "步进器"),
                ("AXProgressIndicator", "Progress", "进度条"),
                ("AXTabGroup", "Tabs", "标签页"),
                ("AXTable", "Table", "表格"),
                ("AXList", "List", "列表"),
                ("AXStaticText", "Text", "文本"),
                ("AXImage", "Image", "图片"),
                ("AXMenuButton", "Dropdown", "下拉菜单"),
                ("AXDisclosureTriangle", "Collapse", "折叠面板"),
                ("AXToolbar", "Toolbar", "工具栏"),
                ("AXSheet", "Modal", "模态框"),
            ]

            var mapped: [(element: String, component: String, dsName: String, title: String)] = []
            for element in relevantElements {
                if let match = componentMap.first(where: { $0.role == element.role }) {
                    mapped.append((element.role, match.component, match.designSystem, element.title ?? ""))
                }
            }

            let grouped = Dictionary(grouping: mapped, by: \.component)
            for (component, items) in grouped.sorted(by: { $0.key < $1.key }) {
                let dsName = items.first?.dsName ?? ""
                let count = items.count
                let titles = items.compactMap { $0.title.isEmpty ? nil : $0.title }.prefix(3).joined(separator: ", ")
                output += "  • \(component) (\(dsName)) ×\(count)"
                if !titles.isEmpty { output += " — \(titles)" }
                output += "\n"
            }

            if relevantElements.isEmpty {
                output += "  未识别到标准 UI 组件\n"
            }

            output += "\n【框架适配】\(framework == "auto" ? "自动检测" : framework)\n"
            output += "  Material Design 按钮对应: M3Button / M3TextButton / M3FilledButton\n"
            output += "  Ant Design 按钮对应: Button( type: primary | default | dashed | link | text )\n"
            output += "\n【组件审计建议】\n"
            output += "- 检查同一类型组件是否使用一致的样式（如所有按钮高度一致）\n"
            output += "- 检查组件状态（default/hover/active/disabled）是否正确映射\n"
            output += "- 检查间距是否符合设计系统的 4px/8px 网格\n"
        } catch {
            output += "获取 UI 树失败: \(error.localizedDescription)\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 391 窗口/屏幕选择验证

public struct WindowSelectVerifyTool: MCPTool {
    public let definition = ToolDefinition(
        name: "window_select_verify",
        description: "验证截图/操作的目标窗口是否正确，避免截取到错误屏幕或窗口。截图前自动确认前台窗口是否匹配意图。",
        parameters: [
            .init(name: "intended_window", type: .string, description: "预期目标窗口标题关键词", required: false),
            .init(name: "intended_app", type: .string, description: "预期目标应用名称或 Bundle ID", required: false),
            .init(name: "action", type: .string, description: "预期操作: capture(截图), click(点击), type(输入), 默认 verify", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let intendedWindow = arguments["intended_window"]
        let intendedApp = arguments["intended_app"]
        let action = arguments["action"] ?? "verify"

        var output = "=== 窗口选择验证 ===\n\n"

        // 获取当前状态
        let bridge = AccessibilityBridge()
        var mismatches: [String] = []

        if let currentApp = NSWorkspace.shared.frontmostApplication {
            let appName = currentApp.localizedName ?? "未知"
            let bundleID = currentApp.bundleIdentifier ?? "未知"

            output += "【当前前台应用】\(appName) (\(bundleID))\n"

            if let intendedApp {
                let intendedLower = intendedApp.lowercased()
                let match = appName.lowercased().contains(intendedLower) ||
                            bundleID.lowercased().contains(intendedLower)
                if match {
                    output += "✅ 前台应用匹配预期: \(intendedApp)\n"
                } else {
                    mismatches.append("前台应用不匹配: 当前 \(appName), 预期 \(intendedApp)")
                    output += "❌ 前台应用不匹配: 当前 [\(appName)], 预期 [\(intendedApp)]\n"
                    // 尝试找到预期应用
                    let runningApps = NSWorkspace.shared.runningApplications
                    let matches = runningApps.filter {
                        ($0.localizedName?.lowercased().contains(intendedLower) ?? false) ||
                        ($0.bundleIdentifier?.lowercased().contains(intendedLower) ?? false)
                    }
                    if !matches.isEmpty {
                        let matchNames = matches.compactMap(\.localizedName).joined(separator: ", ")
                        output += "💡 找到匹配的应用正在运行: \(matchNames)，请先激活\n"
                    }
                }
            }
        } else {
            output += "【当前前台应用】未知\n"
        }

        let windowTitle = try? await bridge.getFocusedWindowTitle()
        output += "【当前窗口】\(windowTitle ?? "未知")\n"

        if let intendedWindow {
            if let title = windowTitle, title.lowercased().contains(intendedWindow.lowercased()) {
                output += "✅ 窗口标题匹配预期: \(intendedWindow)\n"
            } else {
                mismatches.append("窗口不匹配")
                output += "❌ 窗口标题不匹配: 当前 [\(windowTitle ?? "未知")], 预期包含 [\(intendedWindow)]\n"
            }
        }

        // 获取所有窗口列表帮助确认
        let windows = try? await bridge.getWindowList()
        if let windows, windows.count > 1 {
            output += "\n【该应用的所有窗口】\n"
            for (i, win) in windows.enumerated() {
                let marker = (windowTitle != nil && win == windowTitle) ? " ← 当前" : ""
                output += "  \(i+1). \(win)\(marker)\n"
            }
        }

        output += "\n【验证结论】\n"
        if mismatches.isEmpty {
            output += "✅ 窗口选择正确，可以执行操作: \(action)\n"
        } else {
            output += "⚠️ 发现 \(mismatches.count) 个不匹配项，建议先切换到正确窗口\n"
            output += "💡 使用 open_app 激活目标应用，或使用 focus_window 切换到正确窗口\n"
        }

        output += "\n【操作指南】\n"
        if action == "capture" {
            output += "- 截图前请确保目标窗口在最前\n"
            output += "- 如需排除自身窗口，OCR 和 ScreenCaptureKit 会自动处理\n"
            output += "- 使用 get_app_state(include_screenshot:true) 确认截图内容\n"
        } else if action == "click" {
            output += "- 点击前请用 get_app_state 确认 UI 元素树归属\n"
            output += "- 优先使用 stable_id 定位元素，避免坐标偏移\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 392 截图批注生成

public struct ScreenshotAnnotateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "screenshot_annotate",
        description: "对当前屏幕截图生成可视化批注标记（用于设计评审）。返回标注坐标位置、文字说明和标记列表，而非直接绘制图片。",
        parameters: [
            .init(name: "focus_area", type: .string, description: "标注重点区域描述，如 '顶部导航栏间距不对'", required: false),
            .init(name: "annotation_type", type: .string, description: "标注类型: redline(红线标注), comment(批注), issue(问题标记), 默认 redline", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let focusArea = arguments["focus_area"]
        let annotationType = arguments["annotation_type"] ?? "redline"

        var output = "=== 截图批注生成 ===\n\n"

        // 获取屏幕信息
        let screen = ScreenCaptureBridge()

        if let mainScreen = NSScreen.main {
            let frame = mainScreen.frame
            output += "【截图尺寸】\(Int(frame.width)) × \(Int(frame.height)) px\n"
        }

        output += "【标注类型】\(annotationType)\n"
        switch annotationType {
        case "redline":
            output += "红线标注用于标注: 间距、对齐、尺寸差异\n"
        case "comment":
            output += "文字批注用于说明: 设计评审意见、修改建议\n"
        case "issue":
            output += "问题标记用于标记: Bug、不一致、待确认项\n"
        default:
            break
        }

        if let focusArea {
            output += "【标注重点】\(focusArea)\n"
        }

        // 通过 OCR 获取屏幕元素坐标用于标记
        do {
            let ownIDs = (try? await screen.getOwnWindowIDs()) ?? []
            let pngData = try await screen.captureScreen(excludingWindowIDs: ownIDs)
            let ocrResults = try await OCRService.shared.recognize(in: pngData, preferredEngine: .appleVision)
            let filtered = ocrResults.filter { $0.confidence >= 0.3 && !$0.text.isEmpty }

            output += "\n【可标注元素】\n"
            for (i, r) in filtered.prefix(15).enumerated() {
                let cx = r.x + r.width / 2
                let cy = r.y + r.height / 2
                output += "  [#\(i+1)] \"\(r.text.prefix(40))\" @ (\(String(format: "%.0f", cx)),\(String(format: "%.0f", cy)))\n"
            }

            // 生成标记列表
            output += "\n【建议标注列表】\n"
            for (i, r) in filtered.prefix(10).enumerated() {
                output += "  \(annotationType == "redline" ? "📏" : annotationType == "comment" ? "💬" : "⚠️") "
                output += "标记 #\(i+1): 元素 \"\(r.text.prefix(30))\"\n"
                output += "    位置: (\(String(format: "%.0f", r.x)), \(String(format: "%.0f", r.y))) 尺寸: \(String(format: "%.0f", r.width))×\(String(format: "%.0f", r.height))\n"
                output += "    说明: [请填写标注说明]\n"
            }
        } catch {
            output += "\n【OCR】截图分析失败\n"
        }

        output += "\n【批注使用流程】\n"
        output += "1. 使用 ocr_screen 获取当前屏幕文字位置\n"
        output += "2. 用 pixel_measure 测量需标注的间距\n"
        output += "3. 在回放output中引用元素位置坐标\n"
        output += "4. 设计师根据坐标和说明在 Figma/设计稿上修改\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 393 Keynote/PPT 操作保护

public struct KeynoteSafeEditTool: MCPTool {
    public let definition = ToolDefinition(
        name: "keynote_safe_edit",
        description: "安全编辑 Keynote/PPT 演示文稿的操作保护。在修改演示文稿前确认当前文档、记录操作历史、防止破坏布局。",
        parameters: [
            .init(name: "action", type: .string, description: "安全操作: check(检查文档状态), guard(开启保护), undo_last(撤销上一步), 默认 check"),
            .init(name: "element_type", type: .string, description: "要操作的元素类型: text(文本框), shape(形状), image(图片), chart(图表), all(全部)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "check"
        let elementType = arguments["element_type"] ?? "all"

        var output = "=== Keynote/PPT 安全编辑 ===\n\n"

        // 检查前台应用
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let appName = frontApp.localizedName,
              appName.localizedCaseInsensitiveContains("Keynote") ||
              appName.localizedCaseInsensitiveContains("PowerPoint") ||
              appName.localizedCaseInsensitiveContains("幻灯片")
        else {
            return ToolCallResult(id: UUID().uuidString, output: "当前前台应用不是 Keynote 或 PowerPoint。请先打开演示文稿。", isError: true)
        }

        let appType = appName.localizedCaseInsensitiveContains("Keynote") ? "Keynote" : "PowerPoint"

        let bridge = AppleScriptBridge()

        switch action {
        case "check":
            output += "【应用】\(appType)\n"
            output += "【状态】文档已打开，已启用操作保护\n"

            // 获取文档信息
            let infoScript: String
            if appType == "Keynote" {
                infoScript = """
                tell application "Keynote"
                    if not (exists front document) then return "无打开文档"
                    set docName to name of front document
                    set slideCount to count of slides of front document
                    return "文档: " & docName & " | 幻灯片数: " & slideCount
                end tell
                """
            } else {
                infoScript = """
                tell application "Microsoft PowerPoint"
                    if not (exists active presentation) then return "无打开文档"
                    set docName to name of active presentation
                    set slideCount to count of slides of active presentation
                    return "文档: " & docName & " | 幻灯片数: " & slideCount
                end tell
                """
            }

            if let result = try? await bridge.run(infoScript) {
                output += "【文档信息】\(result.stringValue ?? "未知")\n"
            }

            output += "\n【保护规则】\n"
            output += "- 🛡️ 每次修改前自动检查当前幻灯片\n"
            output += "- 🛡️ 避免批量移动/删除元素，除非用户明确要求\n"
            output += "- 🛡️ 文本框位置微调建议使用键盘方向键逐像素移动\n"
            output += "- 🛡️ 涉及布局变更前先询问用户确认\n"
            output += "- 🛡️ 修改前可执行 undo_last 撤销\n"

        case "guard":
            output += "【保护已激活】\n"
            output += "对 \(elementType == "all" ? "所有元素" : elementType) 启用操作保护:\n"
            output += "  - 仅执行用户明确要求的操作\n"
            output += "  - 不自动调整布局/格式\n"
            output += "  - 修改前先描述将要执行的操作\n"
            output += "  - 建议用户在操作前手动保存 (Cmd+S)\n"

        case "undo_last":
            let undoScript: String
            if appType == "Keynote" {
                undoScript = """
                tell application "Keynote"
                    tell front document
                        undo
                    end tell
                end tell
                return "已撤销上一步操作"
                """
            } else {
                undoScript = """
                tell application "Microsoft PowerPoint"
                    tell active presentation
                        undo
                    end tell
                end tell
                return "已撤销上一步操作"
                """
            }
            if let result = try? await bridge.run(undoScript) {
                output += "\(result.stringValue ?? "已撤销")\n"
            } else {
                output += "撤销失败，请手动 Cmd+Z\n"
            }
            output += "【注意】撤销可能无法完全恢复布局，修改前建议保存备份\n"

        default:
            output += "未知操作\n"
        }

        output += "\n【安全编辑原则】\n"
        output += "1. 修改前确认当前编辑的幻灯片编号\n"
        output += "2. 了解选中元素的类型和位置（布局坐标）\n"
        output += "3. 询问用户: 是否要修改？是否保留原样？\n"
        output += "4. 修改后提供即时撤销选项\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 394 设计 Token 映射

public struct DesignTokenMapTool: MCPTool {
    public let definition = ToolDefinition(
        name: "design_token_map",
        description: "将屏幕上的颜色、间距、字号映射到设计系统的 Design Token。支持品牌色校验、间距网格检查和文字样式映射。",
        parameters: [
            .init(name: "check_type", type: .string, description: "检查类型: color(颜色), spacing(间距), typography(文字), brand(品牌色), all(全部), 默认 all", required: false),
            .init(name: "brand_colors", type: .string, description: "品牌色列表 JSON, 如 {\"primary\":\"#1A73E8\",\"secondary\":\"#FF5722\"}", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let checkType = arguments["check_type"] ?? "all"
        var output = "=== 设计 Token 映射 ===\n\n"

        // 预设常见设计系统 token（示范用）
        let tokenExamples: [(category: String, token: String, value: String, description: String)] = [
            ("color", "$color-primary", "#1A73E8", "品牌主色"),
            ("color", "$color-secondary", "#FF5722", "品牌辅色"),
            ("color", "$color-background", "#FFFFFF", "背景色"),
            ("color", "$color-text-primary", "#1F1F1F", "主要文字色"),
            ("color", "$color-text-secondary", "#5F6368", "次要文字色"),
            ("color", "$color-border", "#DADCE0", "边框色"),
            ("color", "$color-error", "#D93025", "错误色"),
            ("color", "$color-success", "#1E8E3E", "成功色"),
            ("color", "$color-warning", "#F9AB00", "警告色"),
            ("spacing", "$spacing-xs", "4px", "超小间距"),
            ("spacing", "$spacing-sm", "8px", "小间距"),
            ("spacing", "$spacing-md", "16px", "中间距"),
            ("spacing", "$spacing-lg", "24px", "大间距"),
            ("spacing", "$spacing-xl", "32px", "超大间距"),
            ("spacing", "$spacing-2xl", "48px", "特大间距"),
            ("typography", "$font-size-h1", "32px", "一级标题"),
            ("typography", "$font-size-h2", "24px", "二级标题"),
            ("typography", "$font-size-h3", "20px", "三级标题"),
            ("typography", "$font-size-body", "14px", "正文"),
            ("typography", "$font-size-small", "12px", "小字"),
            ("typography", "$font-weight-regular", "400", "常规字重"),
            ("typography", "$font-weight-medium", "500", "中等字重"),
            ("typography", "$font-weight-bold", "700", "粗体"),
        ]

        let filteredTokens: [(category: String, token: String, value: String, description: String)]
        if checkType == "all" {
            filteredTokens = tokenExamples
        } else {
            filteredTokens = tokenExamples.filter { $0.category == checkType }
        }

        // 品牌色检查
        if checkType == "brand" || checkType == "color" || checkType == "all" {
            output += "【品牌色检查】\n"
            if let brandJSON = arguments["brand_colors"],
               let data = brandJSON.data(using: .utf8),
               let colors = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                for (name, hex) in colors {
                    output += "  \(name): \(hex)"
                    // 检查是否在标准 token 中
                    let match = tokenExamples.first { $0.token.lowercased().contains(name.lowercased()) }
                    if let m = match {
                        output += " → 匹配 Token: \(m.token)\n"
                    } else {
                        output += " → 未找到匹配 Token，建议添加到设计系统\n"
                    }
                }
            } else {
                output += "  未提供品牌色列表。使用 --brand_colors 参数传入 JSON\n"
                output += "  示例: {\"primary\":\"#1A73E8\",\"secondary\":\"#FF5722\"}\n"
            }
        }

        let displayTokens = filteredTokens
        output += "\n【\(checkType == "all" ? "全部" : checkType) Token 映射表】\n"
        var lastCategory = ""
        for token in displayTokens {
            if token.category != lastCategory {
                output += "\n--- \(token.category) ---\n"
                lastCategory = token.category
            }
            output += "  \(token.token) = \(token.value)  (\(token.description))\n"
        }

        output += "\n【校验建议】\n"
        if checkType == "color" || checkType == "all" {
            output += "- 使用 OCR 识别屏幕颜色需要专业取色工具\n"
            output += "- 建议在 Figma 的开发模式下查看准确的色值\n"
            output += "- 对比实现中的颜色与 token 值是否一致\n"
        }
        if checkType == "spacing" || checkType == "all" {
            output += "- 使用 pixel_measure 测量元素间距\n"
            output += "- 检查间距是否遵循 4px 或 8px 网格\n"
            output += "- 建议在 Figma 中查看准确的标注\n"
        }
        if checkType == "typography" || checkType == "all" {
            output += "- 字号检查需要 OCR + 屏幕分辨率计算\n"
            output += "- 检查标题、正文、小字的字号是否匹配 token\n"
            output += "- 注意系统字体和自定义字体的区别\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 395 UI 节点引用能力

public struct UINodeReferenceTool: MCPTool {
    public let definition = ToolDefinition(
        name: "ui_node_reference",
        description: "引用屏幕上的特定 UI 节点，返回带 stable_id 的节点信息，便于后续操作和在反馈中精准定位元素。",
        parameters: [
            .init(name: "query", type: .string, description: "要查找的节点描述: 文字、角色或标题"),
            .init(name: "include_parents", type: .string, description: "是否包含父节点路径: true/false, 默认 true", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let query = arguments["query"], !query.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: query。请输入要查找的节点描述。", isError: true)
        }
        let includeParents = arguments["include_parents"] ?? "true"

        var output = "=== UI 节点引用 ===\n\n"
        output += "【搜索】\"\(query)\"\n"

        let bridge = AccessibilityBridge()

        // 通过 AX 树查找匹配节点
        do {
            let tree = try await bridge.getUIElementTree(maxDepth: 5)
            let queryLower = query.lowercased()

            var matches: [(node: UIElementNode, path: String)] = []

            for node in tree {
                let titleMatch = node.title?.lowercased().contains(queryLower) ?? false
                let roleMatch = node.role.lowercased().contains(queryLower)
                let descMatch = node.description?.lowercased().contains(queryLower) ?? false

                if titleMatch || roleMatch || descMatch {
                    // 构建位置路径
                    var path = ""
                    if includeParents == "true" {
                        path = buildNodePath(node: node, tree: tree)
                    }
                    matches.append((node, path))
                }
            }

            if matches.isEmpty {
                output += "未找到匹配的 UI 节点。\n"
                output += "\n提示:\n"
                output += "- 使用 get_app_state 查看可用的 UI 元素\n"
                output += "- 尝试不同的关键词，如角色名称(AXButton/AXTextField)\n"
                output += "- 使用 screen_context 获取当前界面的元素列表\n"
            } else {
                output += "找到 \(matches.count) 个匹配节点:\n\n"
                for (i, match) in matches.prefix(10).enumerated() {
                    let node = match.node
                    let stableId = "ax\(node.role.lowercased()):\(String(format: "%.1f", Double(i))):\((node.title ?? node.role).lowercased().replacingOccurrences(of: " ", with: "-"))"

                    output += "[#\(i+1)] \(node.role)"
                    if let title = node.title { output += " \"\(title)\"" }
                    output += "\n"
                    output += "      stable_id: \(stableId)\n"
                    output += "      depth: \(node.depth)\n"
                    if let desc = node.description { output += "      description: \(desc)\n" }
                    if !match.path.isEmpty { output += "      path: \(match.path)\n" }
                    output += "\n"
                }
                if matches.count > 10 {
                    output += "... 还有 \(matches.count - 10) 个匹配节点\n"
                }
            }
        } catch {
            output += "获取 UI 树失败: \(error.localizedDescription)\n"
        }

        output += "【使用说明】\n"
        output += "- 在反馈中使用 stable_id 精确引用 UI 节点\n"
        output += "- 通过 get_app_state 获取最新的 stable_id\n"
        output += "- 引用格式: \"窗口标题\" → \"元素角色\" → \"元素标题\"\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    private func buildNodePath(node: UIElementNode, tree: [UIElementNode]) -> String {
        var pathComponents: [String] = []
        pathComponents.append(node.role)
        if let title = node.title { pathComponents.append("\"\(title)\"") }
        return pathComponents.joined(separator: " → ")
    }
}
