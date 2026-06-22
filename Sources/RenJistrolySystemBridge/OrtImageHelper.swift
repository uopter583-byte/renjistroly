import Foundation
import CoreGraphics

enum OrtImageHelper {
    /// Resize CGImage and convert to NCHW float32 array.
    /// - Parameters:
    ///   - mean: per-channel mean (R, G, B order)
    ///   - std: per-channel std (R, G, B order)
    ///   - scale: applied before normalization, typically 1/255
    static func preprocess(
        _ image: CGImage,
        width: Int,
        height: Int,
        mean: (Float, Float, Float) = (0.485, 0.456, 0.406),
        std: (Float, Float, Float) = (0.229, 0.224, 0.225),
        scale: Float = 1.0 / 255.0
    ) -> [Float] {
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrderDefault.rawValue
        )
        guard let ctx = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else { return [] }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = ctx.data else { return [] }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // ByteOrderDefault = little-endian, noneSkipLast:
        // Memory layout: [B][G][R][X]
        let result = UnsafeMutablePointer<Float>.allocate(capacity: 3 * height * width)
        defer { result.deallocate() }
        let planeSize = height * width

        // Use vDSP for faster normalization? For now, simple loop.
        for i in 0..<planeSize {
            let b = Float(ptr[i * 4 + 0]) * scale
            let g = Float(ptr[i * 4 + 1]) * scale
            let r = Float(ptr[i * 4 + 2]) * scale
            // NCHW: channel 0 = R, channel 1 = G, channel 2 = B
            // PaddleOCR detection model uses BGR mean/std applied to BGR data
            // The mean/std values (0.485, 0.456, 0.406) are ImageNet RGB stats
            result[i] = (r - mean.0) / std.0
            result[planeSize + i] = (g - mean.1) / std.1
            result[2 * planeSize + i] = (b - mean.2) / std.2
        }

        return Array(UnsafeBufferPointer(start: result, count: 3 * planeSize))
    }

    /// Recognition model: mean/std 0.5, output in [-1, 1]
    static func preprocessRec(_ image: CGImage, width: Int, height: Int) -> [Float] {
        preprocess(image, width: width, height: height,
                   mean: (0.5, 0.5, 0.5), std: (0.5, 0.5, 0.5), scale: 1.0 / 255.0)
    }

    /// Detection model: aspect-ratio-preserving resize to maxSide, pad to multiples of 32.
    /// Returns (data, paddedHeight, paddedWidth, ratioH, ratioW).
    static func preprocessDet(
        _ image: CGImage,
        maxSide: Int = 960
    ) -> (data: [Float], padH: Int, padW: Int, ratioH: Float, ratioW: Float) {
        let imgW = image.width
        let imgH = image.height
        let scale = Float(maxSide) / Float(max(imgH, imgW))
        let newH = Int(Float(imgH) * scale)
        let newW = Int(Float(imgW) * scale)
        let padH = ((newH + 31) / 32) * 32
        let padW = ((newW + 31) / 32) * 32
        let ratioH = Float(imgH) / Float(newH)
        let ratioW = Float(imgW) / Float(newW)

        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrderDefault.rawValue
        )
        guard let ctx = CGContext(
            data: nil,
            width: newW, height: newH,
            bitsPerComponent: 8,
            bytesPerRow: newW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else { return ([], 0, 0, 0, 0) }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))

        guard let drawnData = ctx.data else { return ([], 0, 0, 0, 0) }
        let ptr = drawnData.bindMemory(to: UInt8.self, capacity: newW * newH * 4)

        let planeSize = padH * padW
        let result = UnsafeMutablePointer<Float>.allocate(capacity: 3 * planeSize)
        defer { result.deallocate() }
        // Zero-initialize padding
        result.initialize(repeating: 0, count: 3 * planeSize)

        let mean: (Float, Float, Float) = (0.485, 0.456, 0.406)
        let std: (Float, Float, Float) = (0.229, 0.224, 0.225)
        let normScale: Float = 1.0 / 255.0

        for y in 0..<newH {
            for x in 0..<newW {
                let srcIdx = y * newW * 4 + x * 4
                let dstIdx = y * padW + x
                let b = Float(ptr[srcIdx + 0]) * normScale
                let g = Float(ptr[srcIdx + 1]) * normScale
                let r = Float(ptr[srcIdx + 2]) * normScale
                result[dstIdx] = (r - mean.0) / std.0
                result[planeSize + dstIdx] = (g - mean.1) / std.1
                result[2 * planeSize + dstIdx] = (b - mean.2) / std.2
            }
        }

        return (Array(UnsafeBufferPointer(start: result, count: 3 * planeSize)), padH, padW, ratioH, ratioW)
    }
}
