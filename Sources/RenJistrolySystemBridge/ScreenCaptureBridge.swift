import Foundation
import os
import ScreenCaptureKit

public actor ScreenCaptureBridge {
    private var availableContent: SCShareableContent?

    public init() {}

    public func requestPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }

    /// Minimum scale factor (quarter resolution).
    private static let minScale: CGFloat = 0.25
    /// Maximum scale factor (full resolution).
    private static let maxScale: CGFloat = 1.0

    public func captureScreen(
        display: SCDisplay? = nil,
        excludingWindowIDs: [CGWindowID] = [],
        scaleFactor: CGFloat = 1.0
    ) async throws -> Data {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        availableContent = content

        let target = display ?? content.displays.first
        guard let targetDisplay = target else {
            throw ScreenCaptureError.noDisplayAvailable
        }

        let clampedFactor = min(Self.maxScale, max(Self.minScale, scaleFactor))

        let excludedWindows = content.windows.filter { excludingWindowIDs.contains($0.windowID) }
        let filter = SCContentFilter(display: targetDisplay, excludingWindows: excludedWindows)
        let config = SCStreamConfiguration()
        config.width = Int(ceil(CGFloat(targetDisplay.width) * clampedFactor))
        config.height = Int(ceil(CGFloat(targetDisplay.height) * clampedFactor))
        config.scalesToFit = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 1

        let streamOutput = SingleFrameCapture()

        let stream = SCStream(filter: filter, configuration: config, delegate: streamOutput.delegate)
        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: .global())

        return try await withCheckedThrowingContinuation { continuation in
            let done = OSAllocatedUnfairLock(initialState: false)
            streamOutput.onFrame = { data in
                done.withLock { alreadyDone in
                    guard !alreadyDone else { return }
                    alreadyDone = true
                }
                continuation.resume(returning: data)
            }
            streamOutput.onError = { error in
                done.withLock { alreadyDone in
                    guard !alreadyDone else { return }
                    alreadyDone = true
                }
                continuation.resume(throwing: error)
            }

            streamOutput.delegate.onStreamError = { error in
                done.withLock { alreadyDone in
                    guard !alreadyDone else { return }
                    alreadyDone = true
                }
                continuation.resume(throwing: ScreenCaptureError.streamError(error.localizedDescription))
            }

            let sendableStream = UncheckedSendableBox(stream)
            Task {
                do {
                    try await sendableStream.value.startCapture()
                } catch {
                    let shouldResume = done.withLock { alreadyDone in
                        guard !alreadyDone else { return false }
                        alreadyDone = true
                        return true
                    }
                    if shouldResume {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func getOwnWindowIDs() async throws -> [CGWindowID] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        return content.windows
            .filter { $0.owningApplication?.bundleIdentifier == ownBundleID }
            .map(\.windowID)
    }

    public func getAvailableWindows() async throws -> [WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.windows.map { window in
            WindowInfo(
                id: window.windowID,
                title: window.title ?? "",
                bundleID: window.owningApplication?.bundleIdentifier ?? "",
                appName: window.owningApplication?.applicationName ?? "",
                frame: CGRect(
                    x: window.frame.origin.x,
                    y: window.frame.origin.y,
                    width: window.frame.width,
                    height: window.frame.height
                ),
                isOnScreen: window.isOnScreen
            )
        }
    }
}

private final class SingleFrameCapture: NSObject, SCStreamOutput {
    var onFrame: (@Sendable (Data) -> Void)?
    var onError: (@Sendable (Error) -> Void)?
    private var hasCaptured = false
    private let ciContext = CIContext()
    fileprivate let delegate = SingleFrameCaptureDelegate()

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        autoreleasepool {
            guard !hasCaptured else { return }
            hasCaptured = true
            defer { stream.stopCapture() }

            guard type == .screen else { onError?(ScreenCaptureError.imageConversionFailed); return }
            guard let imageBuffer = sampleBuffer.imageBuffer else { onError?(ScreenCaptureError.imageConversionFailed); return }

            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                onError?(ScreenCaptureError.imageConversionFailed)
                return
            }

            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                onError?(ScreenCaptureError.imageConversionFailed)
                return
            }
            onFrame?(pngData)
        }
    }
}

// MARK: - SCStreamDelegate

private final class SingleFrameCaptureDelegate: NSObject, SCStreamDelegate {
    var onStreamError: (@Sendable (Error) -> Void)?

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStreamError?(error)
    }
}

public struct WindowInfo: Sendable, Hashable {
    public let id: CGWindowID
    public let title: String
    public let bundleID: String
    public let appName: String
    public let frame: CGRect
    public let isOnScreen: Bool

    public init(id: CGWindowID, title: String, bundleID: String, appName: String, frame: CGRect, isOnScreen: Bool) {
        self.id = id
        self.title = title
        self.bundleID = bundleID
        self.appName = appName
        self.frame = frame
        self.isOnScreen = isOnScreen
    }
}

// @unchecked Sendable: wraps non-Sendable framework types (SCStream) that are
// used exclusively within a single Task context; no concurrent access.
private final class UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

public enum ScreenCaptureError: Error, LocalizedError, Sendable {
    case noDisplayAvailable
    case imageConversionFailed
    case streamError(String)

    public var errorDescription: String? {
        switch self {
        case .noDisplayAvailable: "未检测到可用显示器。"
        case .imageConversionFailed: "屏幕截图转换失败。"
        case .streamError(let reason): "屏幕流错误：\(reason)"
        }
    }
}
