import AppKit
import Foundation
import RenJistrolyModels

/// Anthropic Computer Use backend: uses Claude vision to locate UI elements and
/// determine interaction coordinates from screenshots. Designed as a smarter
/// alternative to the local Vision backend when AX/DOM fail.
///
/// Architecture:
///   1. Capture screenshot
///   2. Call Anthropic Messages API with image + action-specific prompt
///   3. Parse the structured JSON response
///   4. Execute CGEvents locally
///   5. Return BackendActionResult
public actor AnthropicCUBackend {
    private let apiKey: String?
    private let model: String
    private let session: URLSession
    private let screenCapture: ScreenCaptureBridge

    public init(
        apiKey: String? = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
        model: String = "claude-sonnet-4-6",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.screenCapture = ScreenCaptureBridge()
    }

    public var isAvailable: Bool { (apiKey?.isEmpty) == false }

    /// Execute a MacAction using Anthropic vision for element localization.
    /// Returns the result of the physical action, not the API call.
    public func execute(action: MacAction) async -> BackendActionResult {
        guard isAvailable else {
            return BackendActionResult(
                success: false,
                message: "Anthropic API key 未配置。设置 ANTHROPIC_API_KEY 环境变量或在设置中配置。"
            )
        }

        let screenshotData: Data
        do {
            screenshotData = try await screenCapture.captureScreen()
        } catch {
            return BackendActionResult(success: false, message: "截图失败: \(error.localizedDescription)")
        }

        let base64 = screenshotData.base64EncodedString()
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let prompt = Self.prompt(for: action, screenSize: screenSize)

        let requestBody = buildRequestBody(
            base64: base64,
            prompt: prompt,
            model: model,
            screenSize: screenSize
        )

        guard let apiKey else {
            return BackendActionResult(success: false, message: "Anthropic API key 不可用")
        }

        let rawJSON: String
        do {
            rawJSON = try await callAPI(requestBody: requestBody, apiKey: apiKey)
        } catch {
            return BackendActionResult(success: false, message: "Anthropic API 错误: \(error.localizedDescription)")
        }

        return Self.executeOnScreen(rawJSON: rawJSON, action: action, screenSize: screenSize)
    }

    // MARK: - Prompt Construction

    private static func prompt(for action: MacAction, screenSize: CGSize) -> String {
        let base = "You are a computer vision assistant that locates UI elements on a macOS screen. "
        let dims = "Screen size: \(Int(screenSize.width))x\(Int(screenSize.height)). "

        switch action.kind {
        case .clickAt, .clickElement, .clickFocused:
            let target = action.payload["title"] ?? action.payload["label"] ?? action.payload["description"] ?? action.humanPreview
            return base + dims + """
            The user wants to click on: "\(target)".
            Look at the screenshot and find the most likely position of this element.
            Respond with ONLY a JSON object (no markdown, no code fences):
            {"x": <int>, "y": <int>, "confidence": <0.0-1.0>, "explanation": "<brief reason>"}
            x and y must be within the screen bounds.
            """

        case .doubleClickAt:
            let target = action.payload["title"] ?? action.humanPreview
            return base + dims + """
            The user wants to double-click on: "\(target)".
            Respond with ONLY a JSON object:
            {"x": <int>, "y": <int>, "confidence": <0.0-1.0>, "explanation": "<brief reason>"}
            """

        case .rightClickAt:
            let target = action.payload["title"] ?? action.humanPreview
            return base + dims + """
            The user wants to right-click on: "\(target)".
            Respond with ONLY a JSON object:
            {"x": <int>, "y": <int>, "confidence": <0.0-1.0>, "explanation": "<brief reason>"}
            """

        case .scroll:
            let deltaY = action.payload["delta_y"] ?? "0"
            return base + dims + """
            The user wants to scroll (delta_y=\(deltaY)).
            Identify the scrollable area and return a click point to focus it first.
            If the area is already in focus, return {"scroll_directly": true, "x": 0, "y": 0, "confidence": 1.0, "explanation": "focused"}.
            Otherwise return {"x": <int>, <y>: <int>, "confidence": <0.0-1.0>, "explanation": "<reason>"}.
            """

        case .drag:
            let fromDesc = action.payload["from_desc"] ?? action.payload["from_x"].map { "x:\($0)" } ?? "?"
            let toDesc = action.payload["to_desc"] ?? action.payload["to_x"].map { "x:\($0)" } ?? "?"
            return base + dims + """
            The user wants to drag from "\(fromDesc)" to "\(toDesc)".
            Find the source element. Respond with ONLY:
            {"from_x": <int>, "from_y": <int>, "to_x": <int>, "to_y": <int>, "confidence": <0.0-1.0>, "explanation": "<reason>"}
            """

        case .openApplication:
            let appName = action.payload["app_name"] ?? action.payload["app"] ?? action.humanPreview
            return base + dims + """
            The user wants to open "\(appName)".
            Do you see an icon for "\(appName)" in the Dock or Dock folder?
            If yes, return coordinates to click it.
            If not visible, return {"not_visible": true, "x": 0, "y": 0, "confidence": 0.0, "explanation": "App icon not visible on screen"}.
            """

        case .insertText, .setFocusedText:
            let text = action.payload["text"] ?? action.payload["value"] ?? ""
            return base + dims + """
            The user wants to type: "\(text)".
            First check the screenshot: is a text field already focused (has cursor/caret)?
            If yes: {"focused": true, "explanation": "text field is ready"}
            If no: {"focused": false, "x": <int>, "y": <int>, "explanation": "click here first to focus the text field"}
            """

        default:
            return base + dims + """
            The user wants to perform: "\(action.humanPreview)".
            Look at the screenshot and determine how to assist.
            If this is a click-type action, return coordinates.
            Otherwise return: {"no_action_needed": true, "explanation": "explain what was observed"}
            """
        }
    }

    // MARK: - Response Execution

    private static func executeOnScreen(rawJSON: String, action: MacAction, screenSize: CGSize) -> BackendActionResult {
        guard let jsonStart = rawJSON.firstIndex(of: "{"),
              let jsonEnd = rawJSON.lastIndex(of: "}"),
              jsonStart < jsonEnd,
              let data = rawJSON[jsonStart...jsonEnd].data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return BackendActionResult(success: false, message: "无法解析 Anthropic 响应: \(String(rawJSON.prefix(200)))")
        }

        let explanation = json["explanation"] as? String ?? ""

        // no_action_needed / not_visible / focused responses
        if json["no_action_needed"] as? Bool == true {
            return BackendActionResult(success: true, message: "无需操作: \(explanation)")
        }
        if json["not_visible"] as? Bool == true {
            return BackendActionResult(success: false, message: "目标元素未在屏幕上找到: \(explanation)")
        }
        if json["focused"] as? Bool == true, action.kind == .insertText || action.kind == .setFocusedText {
            return BackendActionResult(success: true, message: "文本框已就绪，可以直接输入")
        }
        if json["scroll_directly"] as? Bool == true {
            return BackendActionResult(success: true, message: "滚动区域已就绪，可以直接滚动")
        }

        // Coordinate-based actions: click, double-click, right-click
        let confidence = json["confidence"] as? Double ?? 0.0

        // Drag action needs two coordinate pairs
        if action.kind == .drag {
            let fromX = json["from_x"] as? Double ?? json["x"] as? Double ?? -1
            let fromY = json["from_y"] as? Double ?? json["y"] as? Double ?? -1
            let toX = json["to_x"] as? Double ?? -1
            let toY = json["to_y"] as? Double ?? -1
            guard fromX >= 0, fromY >= 0, toX >= 0, toY >= 0 else {
                return BackendActionResult(success: false, message: "Anthropic 未返回有效拖拽坐标: \(explanation)")
            }
            guard confidence >= 0.5 else {
                return BackendActionResult(success: false, message: "Anthropic 置信度过低(\(confidence)): \(explanation)")
            }
            return executeDrag(from: CGPoint(x: fromX, y: fromY), to: CGPoint(x: toX, y: toY), confidence: confidence, explanation: explanation, screenSize: screenSize)
        }

        // Text input needs focus coordinates
        if action.kind == .insertText || action.kind == .setFocusedText {
            if let x = json["x"] as? Double, let y = json["y"] as? Double, x >= 0, y >= 0 {
                return executeClick(at: CGPoint(x: x, y: y), confidence: confidence, explanation: explanation, screenSize: screenSize, clickCount: 1)
            }
            return BackendActionResult(success: true, message: "无法定位文本框: \(explanation)")
        }

        // Standard coordinate click
        let x = json["x"] as? Double ?? -1
        let y = json["y"] as? Double ?? -1
        guard x >= 0, y >= 0, x <= screenSize.width, y <= screenSize.height else {
            return BackendActionResult(success: false, message: "坐标无效 (\(x), \(y)) 或超出屏幕: \(explanation)")
        }
        guard confidence >= 0.5 else {
            return BackendActionResult(success: false, message: "Anthropic 置信度过低(\(confidence)): \(explanation)")
        }

        let clickCount: Int
        switch action.kind {
        case .doubleClickAt: clickCount = 2
        default: clickCount = 1
        }
        return executeClick(at: CGPoint(x: x, y: y), confidence: confidence, explanation: explanation, screenSize: screenSize, clickCount: clickCount)
    }

    // MARK: - Physical Execution

    private static func executeClick(at point: CGPoint, confidence: Double, explanation: String, screenSize: CGSize, clickCount: Int = 1) -> BackendActionResult {
        let location = CGEventTapLocation.cghidEventTap
        for _ in 0..<clickCount {
            let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
            let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
            down?.post(tap: location)
            up?.post(tap: location)
            if clickCount > 1 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        return BackendActionResult(
            success: true,
            message: "Anthropic CU 定位点击 (\(Int(point.x)), \(Int(point.y))), 置信度 \(String(format: "%.2f", confidence)): \(explanation)"
        )
    }

    private static func executeDrag(from: CGPoint, to: CGPoint, confidence: Double, explanation: String, screenSize: CGSize) -> BackendActionResult {
        let location = CGEventTapLocation.cghidEventTap
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: from, mouseButton: .left)
        down?.post(tap: location)
        Thread.sleep(forTimeInterval: 0.1)
        let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: to, mouseButton: .left)
        drag?.post(tap: location)
        Thread.sleep(forTimeInterval: 0.1)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: to, mouseButton: .left)
        up?.post(tap: location)
        return BackendActionResult(
            success: true,
            message: "Anthropic CU 拖拽 (\(Int(from.x)), \(Int(from.y)))→(\(Int(to.x)), \(Int(to.y))), 置信度 \(String(format: "%.2f", confidence)): \(explanation)"
        )
    }

    // MARK: - API Call

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    private func buildRequestBody(base64: String, prompt: String, model: String, screenSize: CGSize) -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "temperature": 0.0,
            "system": "You are a precise computer vision assistant. Your task is to analyze macOS screenshots and return exact screen coordinates of UI elements. Always respond with valid JSON only. Never include markdown code fences or extra text.",
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/png", "data": base64]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    private func callAPI(requestBody: Data, apiKey: String) async throws -> String {
        guard let url = URL(string: baseURL) else { throw AnthropicCUError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = requestBody
        urlRequest.timeoutInterval = 60

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicCUError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AnthropicCUError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String
        else {
            throw AnthropicCUError.parseFailed
        }
        return text
    }
}

public enum AnthropicCUError: Error, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case parseFailed
}

extension AnthropicCUError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "API 地址配置错误"
        case .invalidResponse: return "服务器返回了无法解析的响应"
        case .httpError(let code, let body): return "请求失败 (HTTP \(code)): \(body)"
        case .parseFailed: return "无法解析 API 响应"
        }
    }
}
