import AppKit
import CoreGraphics
import Foundation
import RenJistrolyModels
import ScreenCaptureKit
import Vision

public actor ScreenContextProvider {
    public init() {}

    private var isCapturing = false

    public func captureCurrentScreen(includeImageData: Bool = false, skipOwnWindows: Bool = false) async -> ScreenContext {
        if isCapturing { return ScreenContext(displayDescription: "Screen capture in progress.") }
        isCapturing = true
        defer { isCapturing = false }
        let displayCount = NSScreen.screens.count
        let main = NSScreen.main
        let windows = visibleWindows(skipOwnWindows: skipOwnWindows)
        let windowSummary = windows.prefix(8).map { window in
            if let title = window.windowTitle, !title.isEmpty {
                return "\(window.ownerName): \(title)"
            }
            return window.ownerName
        }.joined(separator: " | ")
        let description = "Displays: \(displayCount), main frame: \(main?.frame.debugDescription ?? "unknown")"

        guard includeImageData else {
            return ScreenContext(
                displayDescription: "\(description). Visible windows: \(windowSummary). Visual capture not requested.",
                visibleWindows: windows
            )
        }

        // ScreenCaptureKit's SCShareableContent.excludingDesktopWindows and
        // SCScreenshotManager.captureImage handle permission checking natively.
        // On macOS 26+, the older CGPreflightScreenCaptureAccess / CGRequestScreenCaptureAccess
        // APIs are deprecated and their permission state diverges from ScreenCaptureKit's.
        // Rely on SCShareableContent — it will silently fail if permission was denied
        // and the catch block below handles that gracefully.
        do {
            let images = try await captureAllDisplayImages()
            guard !images.isEmpty else {
                return ScreenContext(displayDescription: "\(description). Screen capture returned no image.")
            }
            var allText: [String] = []
            for image in images {
                if let text = try? await recognizeText(in: image) {
                    allText.append(text)
                }
            }
            let ocr = allText.joined(separator: "\n")
            Task.detached { await AgentEventBus.shared.publish(.desktop(.screenCaptured(ocrCharCount: ocr.count, windowCount: windows.count))) }
            return ScreenContext(
                displayDescription: "\(description). Visible windows: \(windowSummary). OCR across \(images.count) display(s), \(ocr.count) chars.",
                imageData: nil,
                recognizedText: ocr,
                visibleWindows: windows
            )
        } catch {
            return ScreenContext(
                displayDescription: "\(description). Visible windows: \(windowSummary). Screen OCR failed: \(error.localizedDescription)",
                imageData: nil,
                visibleWindows: windows
            )
        }
    }

    private func visibleWindows(skipOwnWindows: Bool = false) -> [VisibleWindowContext] {
        guard let rawWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return rawWindows.compactMap { info in
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  !owner.isEmpty,
                  owner != "Window Server",
                  owner != "Dock" else {
                return nil
            }
            let ownerPID = info[kCGWindowOwnerPID as String] as? Int ?? 0
            if skipOwnWindows, ownerPID == ProcessInfo.processInfo.processIdentifier || owner == "RenJistroly" {
                return nil
            }
            let title = info[kCGWindowName as String] as? String
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            let bounds = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let x = Int(bounds["X"] as? Double ?? 0)
            let y = Int(bounds["Y"] as? Double ?? 0)
            let width = Int(bounds["Width"] as? Double ?? 0)
            let height = Int(bounds["Height"] as? Double ?? 0)
            guard width > 80, height > 60 else { return nil }
            return VisibleWindowContext(
                ownerName: owner,
                windowTitle: title,
                layer: layer,
                boundsDescription: "x:\(x), y:\(y), w:\(width), h:\(height)"
            )
        }
    }

    private func captureAllDisplayImages() async throws -> [CGImage] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard !content.displays.isEmpty else { return [] }
        var images: [CGImage] = []
        for display in content.displays {
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false
            if let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) {
                images.append(image)
            }
        }
        return images
    }

    private func captureMainDisplayImage() async throws -> CGImage? {
        let images = try await captureAllDisplayImages()
        return images.first
    }

    private func downscaleIfNeeded(_ image: CGImage, maxDimension: Int) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > maxDimension || height > maxDimension else { return image }
        let scale = min(Double(maxDimension) / Double(width), Double(maxDimension) / Double(height))
        let newWidth = Int(Double(width) * scale)
        let newHeight = Int(Double(height) * scale)
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }

    private func recognizeText(in image: CGImage) async throws -> String {
        let scaled = downscaleIfNeeded(image, maxDimension: 2560)
        let enhanced = Self.enhanceContrast(scaled) ?? scaled
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.recognitionLevel = .accurate
            request.minimumTextHeight = 0.005
            let handler = VNImageRequestHandler(cgImage: enhanced)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func enhanceContrast(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        guard let contrast = CIFilter(name: "CIColorControls") else { return nil }
        contrast.setValue(ciImage, forKey: kCIInputImageKey)
        contrast.setValue(3.0, forKey: kCIInputContrastKey)
        contrast.setValue(0.05, forKey: kCIInputBrightnessKey)
        contrast.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let output = contrast.outputImage else { return nil }
        let ctx = CIContext(options: [.workingColorSpace: NSNull()])
        return ctx.createCGImage(output, from: output.extent)
    }
}
