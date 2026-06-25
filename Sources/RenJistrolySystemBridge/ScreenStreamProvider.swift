import CoreGraphics
import Foundation
import ScreenCaptureKit
import OSLog

/// Continuous screen-frame stream powered by ScreenCaptureKit.
///
/// Usage:
/// ```swift
/// let provider = ScreenStreamProvider()
/// await provider.startStream(fps: 5)
/// for await frame in await provider.frames {
///     // use CGImage
/// }
/// ```
public actor ScreenStreamProvider {

    /// Minimum scale factor (quarter resolution).
    private static let minScale: CGFloat = 0.25
    /// Maximum scale factor (full resolution).
    private static let maxScale: CGFloat = 1.0

    public enum StreamError: LocalizedError {
        case noDisplayAvailable
        case alreadyRunning
        case streamCreationFailed(String)
        case startFailed(Error)

        public var errorDescription: String? {
            switch self {
            case .noDisplayAvailable: return "没有可用的显示器"
            case .alreadyRunning: return "屏幕流已在运行"
            case .streamCreationFailed(let d): return "创建屏幕流失败: \(d)"
            case .startFailed(let e): return "启动屏幕流失败: \(e.localizedDescription)"
            }
        }
    }

    public struct FrameEvent: Sendable {
        public let cgImage: CGImage
        public let capturedAt: Date
    }

    private var stream: SCStream?
    private var output: StreamOutput?
    private var _frameContinuation: AsyncStream<FrameEvent>.Continuation?
    private var isStreaming = false
    private var frameCount = 0
    private var lastFrameAt: Date?
    private var streamFPS: Int = 4
    private var streamExcludeOwnWindows: Bool = true
    private var streamScaleFactor: CGFloat = 0.5
    private var healthCheckTask: Task<Void, Never>?

    /// Async stream of captured frames. Subscribe before calling `startStream`.
    /// Each frame is delivered as a `FrameEvent` containing the CGImage and timestamp.
    public private(set) lazy var frames: AsyncStream<FrameEvent> = {
        AsyncStream { [weak self] cont in
            Task { [weak self] in
                await self?.configureContinuation(cont)
            }
        }
    }()

    private func configureContinuation(_ cont: AsyncStream<FrameEvent>.Continuation) {
        _frameContinuation = cont
    }

    public init() {}

    /// Start streaming at the given FPS. Call `stopStream()` to end.
    /// - Parameters:
    ///   - fps: Target frames per second (clamped 1-30). Default 4 is a good balance.
    ///   - excludeOwnWindows: If true, filters out RenJistroly's own windows from the capture.
    ///   - scaleFactor: Downscaling factor applied to the capture resolution (clamped 0.25-1.0).
    ///                  Default 0.5 halves the pixel dimensions for significant bandwidth savings.
    public func startStream(fps: Int = 4, excludeOwnWindows: Bool = true, scaleFactor: CGFloat = 0.5) async throws {
        guard !isStreaming else { throw StreamError.alreadyRunning }

        streamFPS = fps
        streamExcludeOwnWindows = excludeOwnWindows
        streamScaleFactor = clampScaleFactor(scaleFactor)

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw StreamError.noDisplayAvailable
        }

        let filter: SCContentFilter
        var excludedIDs = Set<CGWindowID>()
        if excludeOwnWindows, let ownBundleID = Bundle.main.bundleIdentifier {
            excludedIDs = Set(content.windows.filter { $0.owningApplication?.bundleIdentifier == ownBundleID }.compactMap(\.windowID))
            if excludedIDs.isEmpty {
                filter = SCContentFilter(display: display, excludingWindows: [])
            } else {
                filter = SCContentFilter(display: display, excludingWindows: Array(content.windows.filter { window in
                    let wid = window.windowID
                    return !excludedIDs.contains(wid)
                }))
            }
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
        }

        let config = SCStreamConfiguration()
        config.width = Int(ceil(CGFloat(display.width) * streamScaleFactor))
        config.height = Int(ceil(CGFloat(display.height) * streamScaleFactor))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(1, min(fps, 30))))
        config.showsCursor = true

        let output = StreamOutput { [weak self] image in
            Task { [weak self] in
                await self?.deliverFrame(image)
            }
        }
        self.output = output

        let streamDelegate = StreamDelegateImpl { [weak self] error in
            Task { [weak self] in
                os_log(.fault, "[ScreenStream] 流意外停止: %{public}@", error.localizedDescription)
                await self?.restartStream()
            }
        }
        let newStream = SCStream(filter: filter, configuration: config, delegate: streamDelegate)
        try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
        stream = newStream

        do {
            try await newStream.startCapture()
            isStreaming = true
            lastFrameAt = Date()
            os_log("[ScreenStream] 开始流式传输，fps=%d", log: .default, fps)
        } catch {
            self.stream = nil
            self.output = nil
            throw StreamError.startFailed(error)
        }

        startHealthCheck()
    }

    /// Stop the stream and deliver a final `nil` frame to end the async sequence.
    public func stopStream() async {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        guard isStreaming else { return }
        isStreaming = false
        frameCount = 0
        lastFrameAt = nil
        try? await stream?.stopCapture()
        if let output { try? stream?.removeStreamOutput(output, type: .screen) }
        stream = nil
        output = nil
        _frameContinuation?.finish()
        _frameContinuation = nil
        os_log("[ScreenStream] 停止流式传输", log: .default)
    }

    /// Whether the stream is currently active.
    public var isActive: Bool { isStreaming }

    // MARK: - Private

    private func deliverFrame(_ image: CGImage) {
        guard isStreaming else { return }
        frameCount += 1
        lastFrameAt = Date()
        let event = FrameEvent(cgImage: image, capturedAt: Date())
        _frameContinuation?.yield(event)
    }

    private func startHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                let isHealthy = await self.checkFrameHealth()
                if !isHealthy {
                    os_log("[ScreenStream] 帧流停滞超过 10 秒，正在重启", log: .default, type: .fault)
                    await self.restartStream()
                    return
                }
            }
        }
    }

    private func checkFrameHealth() async -> Bool {
        guard isStreaming, let lastFrame = lastFrameAt else { return true }
        return lastFrame + 10 > Date()
    }

    private func restartStream() async {
        let fps = streamFPS
        let excludeOwn = streamExcludeOwnWindows
        let scaleFactor = streamScaleFactor
        await stopStream()
        do {
            try await startStream(fps: fps, excludeOwnWindows: excludeOwn, scaleFactor: scaleFactor)
        } catch {
            os_log(.fault, log: .default, "[ScreenStream] 重启失败: %{public}@", error.localizedDescription)
        }
    }

    /// Clamp the scale factor to the allowed range.
    private func clampScaleFactor(_ value: CGFloat) -> CGFloat {
        min(Self.maxScale, max(Self.minScale, value))
    }
}

// MARK: - SCStreamOutput

private final class StreamOutput: NSObject, SCStreamOutput {
    private let onFrame: (CGImage) -> Void
    private let ciContext = CIContext()

    init(onFrame: @escaping (CGImage) -> Void) {
        self.onFrame = onFrame
    }

    func stream(_ stream: SCStream, didOutput sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        autoreleasepool {
            guard outputType == .screen,
                  let imageBuffer = sampleBuffer.imageBuffer else { return }

            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
            onFrame(cgImage)
        }
    }
}

// MARK: - SCStreamDelegate

private final class StreamDelegateImpl: NSObject, SCStreamDelegate {
    private let onStreamStopped: (Error) -> Void

    init(onStreamStopped: @escaping (Error) -> Void) {
        self.onStreamStopped = onStreamStopped
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStreamStopped(error)
    }
}
