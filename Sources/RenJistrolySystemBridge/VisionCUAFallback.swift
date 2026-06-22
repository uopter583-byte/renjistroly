import Foundation
import RenJistrolyModels

/// Configuration for vision-based CUA, holding an optional LLM backend reference.
public struct VisionCUAConfig: Sendable {
    public let llmBackend: LLMBackend?

    public init(llmBackend: LLMBackend?) {
        self.llmBackend = llmBackend
    }
}

/// Vision-based CUA fallback: screenshot -> vision model -> coordinate -> CGEvent.
/// Used when AX/DOM backends fail to find or interact with an element.
public actor VisionCUAFallback {
    public enum Strategy: String, Sendable, Codable {
        case llamaVision   /// Local MLX vision model
        case claudeVision  /// Claude API image analysis
        case openAIVision  /// OpenAI vision (GPT-4o)
    }

    public nonisolated let strategy: Strategy
    public private(set) var lastAnalysis: VisionCUAResult?
    private var config: VisionCUAConfig

    public init(strategy: Strategy = .claudeVision, config: VisionCUAConfig = .init(llmBackend: nil)) {
        self.strategy = strategy
        self.config = config
    }

    /// Update the LLM backend used for vision analysis after initialization.
    public func setLLMBackend(_ backend: LLMBackend?) {
        config = VisionCUAConfig(llmBackend: backend)
    }

    /// Analyze a screenshot to find coordinates for a given action description.
    /// Returns the best-guess screen coordinate for the target element.
    public func analyze(screenshotBase64: String, instruction: String) async -> VisionCUAResult {
        if strategy == .claudeVision, let backend = config.llmBackend, await backend.isAvailable {
            let result = await analyzeWithVisionLLM(screenshotBase64: screenshotBase64, instruction: instruction, backend: backend)
            lastAnalysis = result
            return result
        }

        let result = VisionCUAResult(
            strategy: strategy,
            instruction: instruction,
            confidence: 0.4,
            targetRect: nil,
            tapPoint: nil,
            explanation: "Vision analysis unavailable. Configure a CloudAnthropic backend."
        )
        lastAnalysis = result
        return result
    }

    // MARK: - Private

    private func analyzeWithVisionLLM(screenshotBase64: String, instruction: String, backend: LLMBackend) async -> VisionCUAResult {
        let llmConfig = LLMConfiguration.defaultCloud

        let message = Message(
            role: .user,
            content: [
                .image(.base64(screenshotBase64, mimeType: "image/png")),
                .text("You are a computer vision assistant. Look at the screenshot. The user wants to: \(instruction). Return the most likely screen coordinate (x,y) of the target element. Respond with ONLY a JSON object like {\"x\": 100, \"y\": 200, \"explanation\": \"brief reason\"}.")
            ]
        )

        do {
            let response = try await backend.chat(
                messages: [message],
                config: llmConfig,
                tools: nil,
                delegate: nil
            )

            let text = response.textContent
            let (coordinate, confidence, explanation) = parseCoordinateResponse(text)

            var tapPoint: CGPoint?
            var targetRect: CGRect?
            if let coord = coordinate {
                tapPoint = CGPoint(x: CGFloat(coord.x), y: CGFloat(coord.y))
                targetRect = CGRect(
                    x: CGFloat(coord.x) - 10,
                    y: CGFloat(coord.y) - 10,
                    width: 20,
                    height: 20
                )
            }

            return VisionCUAResult(
                strategy: strategy,
                instruction: instruction,
                confidence: confidence,
                targetRect: targetRect,
                tapPoint: tapPoint,
                explanation: explanation
            )
        } catch {
            return VisionCUAResult(
                strategy: strategy,
                instruction: instruction,
                confidence: 0.2,
                targetRect: nil,
                tapPoint: nil,
                explanation: "Vision LLM error: \(error.localizedDescription)"
            )
        }
    }

    private func parseCoordinateResponse(_ text: String) -> (coordinate: (x: Int, y: Int)?, confidence: Double, explanation: String) {
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}"),
              jsonStart < jsonEnd else {
            return (nil, 0.3, "No JSON object found in response")
        }

        let jsonString = text[jsonStart ... jsonEnd]
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, 0.3, "Could not parse coordinate JSON")
        }

        let explanation = json["explanation"] as? String ?? "Parsed from vision response"

        if let x = json["x"] as? Int, let y = json["y"] as? Int {
            return ((x, y), 0.7, explanation)
        }
        if let x = json["x"] as? Double, let y = json["y"] as? Double {
            return ((Int(x), Int(y)), 0.7, explanation)
        }

        return (nil, 0.3, "Coordinate JSON missing x/y keys")
    }
}

public struct VisionCUAResult: Sendable, Codable {
    public let strategy: VisionCUAFallback.Strategy
    public let instruction: String
    public let confidence: Double
    public let targetRect: CGRect?
    public let tapPoint: CGPoint?
    public let explanation: String

    public init(strategy: VisionCUAFallback.Strategy, instruction: String, confidence: Double, targetRect: CGRect?, tapPoint: CGPoint?, explanation: String) {
        self.strategy = strategy
        self.instruction = instruction
        self.confidence = confidence
        self.targetRect = targetRect
        self.tapPoint = tapPoint
        self.explanation = explanation
    }
}
