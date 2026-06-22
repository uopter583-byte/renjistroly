import Foundation

public struct DetectedTextBox: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let confidence: Float

    public init(x: Double, y: Double, width: Double, height: Double, confidence: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.confidence = confidence
    }
}

public struct DBPostProcessor: Sendable {
    public let threshold: Float
    public let boxThreshold: Float
    public let maxCandidates: Int
    public let unclipRatio: Double
    public let minSize: Int

    public init(
        threshold: Float = 0.2,
        boxThreshold: Float = 0.4,
        maxCandidates: Int = 1000,
        unclipRatio: Double = 1.4,
        minSize: Int = 5
    ) {
        self.threshold = threshold
        self.boxThreshold = boxThreshold
        self.maxCandidates = maxCandidates
        self.unclipRatio = unclipRatio
        self.minSize = minSize
    }

    public func process(heatmap: [Float], mapWidth: Int, mapHeight: Int, imageWidth: Int, imageHeight: Int) -> [DetectedTextBox] {
        let w = mapWidth
        let h = mapHeight
        guard w > 0, h > 0, heatmap.count >= w * h else { return [] }

        var bitmap = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            bitmap[i] = heatmap[i] > threshold ? 1 : 0
        }

        let components = findConnectedComponents(bitmap: bitmap, width: w, height: h)
        var results: [DetectedTextBox] = []

        for comp in components.prefix(maxCandidates) {
            let minSide = min(comp.width, comp.height)
            if minSide < minSize { continue }

            let score = boxScore(heatmap: heatmap, mapWidth: w, mapHeight: h,
                                 x: comp.x, y: comp.y, width: comp.width, height: comp.height)
            if score < boxThreshold { continue }

            let cx = Double(comp.x) + Double(comp.width) / 2.0
            let cy = Double(comp.y) + Double(comp.height) / 2.0
            let uw = Double(comp.width) * unclipRatio
            let uh = Double(comp.height) * unclipRatio

            let nx = max(0, cx - uw / 2.0)
            let ny = max(0, cy - uh / 2.0)
            let nw = min(Double(w) - nx, uw)
            let nh = min(Double(h) - ny, uh)

            let imgX = nx / Double(w) * Double(imageWidth)
            let imgY = ny / Double(h) * Double(imageHeight)
            let imgW = nw / Double(w) * Double(imageWidth)
            let imgH = nh / Double(h) * Double(imageHeight)

            results.append(DetectedTextBox(
                x: imgX, y: imgY, width: imgW, height: imgH, confidence: score
            ))
        }

        return results
    }

    // MARK: - Connected Components

    private struct Component {
        let x: Int; let y: Int; let width: Int; let height: Int; let pixelCount: Int
    }

    private func findConnectedComponents(bitmap: [UInt8], width: Int, height: Int) -> [Component] {
        var visited = [Bool](repeating: false, count: width * height)
        var components: [Component] = []

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if bitmap[idx] == 0 || visited[idx] { continue }

                var queue: [(Int, Int)] = [(x, y)]
                visited[idx] = true
                var front = 0

                var minX = x; var maxX = x
                var minY = y; var maxY = y
                var count = 0

                while front < queue.count && queue.count < width * height {
                    let (cx, cy) = queue[front]
                    front += 1
                    count += 1
                    minX = min(minX, cx); maxX = max(maxX, cx)
                    minY = min(minY, cy); maxY = max(maxY, cy)

                    for (dx, dy) in [(0,1),(1,0),(0,-1),(-1,0),(1,1),(1,-1),(-1,1),(-1,-1)] {
                        let nx = cx + dx; let ny = cy + dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let nIdx = ny * width + nx
                        if bitmap[nIdx] == 1 && !visited[nIdx] {
                            visited[nIdx] = true
                            queue.append((nx, ny))
                        }
                    }
                }

                components.append(Component(
                    x: minX, y: minY,
                    width: maxX - minX + 1,
                    height: maxY - minY + 1,
                    pixelCount: count
                ))
            }
        }

        return components.sorted { $0.pixelCount > $1.pixelCount }
    }

    // MARK: - Scoring

    private func boxScore(heatmap: [Float], mapWidth: Int, mapHeight: Int, x: Int, y: Int, width: Int, height: Int) -> Float {
        guard width > 0, height > 0 else { return 0 }
        var sum: Float = 0
        var count = 0
        for py in y..<(y + height) {
            guard py >= 0, py < mapHeight else { continue }
            for px in x..<(x + width) {
                guard px >= 0, px < mapWidth else { continue }
                sum += heatmap[py * mapWidth + px]
                count += 1
            }
        }
        return count > 0 ? sum / Float(count) : 0
    }
}
