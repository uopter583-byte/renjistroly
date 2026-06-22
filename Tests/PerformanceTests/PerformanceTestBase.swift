import XCTest
import Foundation

// MARK: - Performance test base class

/// Base class for all RenJistroly performance benchmarks.
///
/// Provides:
/// - `measureBlock` — wrapped `measure` with result recording
/// - `trackMemory` — malloc / VM footprint delta before/after a closure
/// - `countOperations` — coarse operation throughput measurement
/// - `BenchResult` — structured result with threshold checking
/// - `recordResult` — stores results for later report generation
///
/// Subclasses override `thresholds()` to define pass/fail per test.
open class PerformanceTestBase: XCTestCase {

    // MARK: - Result model

    public struct BenchResult: Sendable {
        public let name: String
        public let metric: BenchMetric
        public let value: Double
        public let unit: String
        public let threshold: BenchmarkThreshold
        public let iterations: Int
        public let metadata: [String: String]
        public let timestamp: Date

        public var passed: Bool {
            switch threshold {
            case .max(let limit): value <= limit
            case .min(let limit): value >= limit
            case .range(let lo, let hi): value >= lo && value <= hi
            }
        }
    }

    public enum BenchMetric: String, Sendable, Codable {
        case duration       // seconds or milliseconds
        case memory         // bytes
        case throughput     // ops/sec
        case count          // integer count
    }

    public enum BenchmarkThreshold: Sendable {
        case max(Double)
        case min(Double)
        case range(Double, Double)

        public var description: String {
            switch self {
            case .max(let v): "< \(v)"
            case .min(let v): "> \(v)"
            case .range(let lo, let hi): "[\(lo), \(hi)]"
            }
        }
    }

    // MARK: - Collected results

    private static let resultsLock = NSLock()
    private static nonisolated(unsafe) var _allResults: [BenchResult] = []

    /// All results from this test run, thread-safe.
    public static var allResults: [BenchResult] {
        resultsLock.withLock { _allResults }
    }

    /// Clear all accumulated results.
    public static func resetResults() {
        resultsLock.withLock { _allResults.removeAll() }
    }

    // MARK: - Hooks for subclasses

    /// Override to define per-test thresholds. Called once during `setUp`.
    open func thresholds() -> [String: BenchmarkThreshold] { [:] }

    private var activeThresholds: [String: BenchmarkThreshold] = [:]

    open override func setUp() {
        super.setUp()
        activeThresholds = thresholds()
    }

    // MARK: - Measurement helpers

    /// Equivalent to `measure {}` but returns the measured duration in seconds
    /// and records a `BenchResult` via `recordResult`.
    public func measureBlock(
        name: String,
        iterations: Int = 5,
        threshold: BenchmarkThreshold? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) rethrows -> Double {
        let count = max(1, iterations)

        measure(metrics: [XCTClockMetric()]) {
            try? block()
        }

        // XCTest `measure` runs `iterations` internally; we grab its average.
        // For manual control we run the block ourselves and divide.
        var raw: [Double] = []
        raw.reserveCapacity(count)
        for _ in 0 ..< count {
            let start = CACurrentMediaTime()
            try? block()
            let elapsed = CACurrentMediaTime() - start
            raw.append(elapsed)
        }

        // Drop first (warm-up) if we have enough samples
        if raw.count > 2 { raw.removeFirst() }
        let avg = raw.reduce(0, +) / Double(raw.count)

        let effectiveThreshold = threshold ?? activeThresholds[name] ?? .max(.infinity)
        let result = BenchResult(
            name: name,
            metric: .duration,
            value: avg,
            unit: "s",
            threshold: effectiveThreshold,
            iterations: count,
            metadata: ["samples": "\(raw.count)", "min": "\(raw.min() ?? 0)", "max": "\(raw.max() ?? 0)"],
            timestamp: Date()
        )
        recordResult(result)
        return avg
    }

    /// Async variant of `measureBlock`.
    public func measureBlockAsync(
        name: String,
        iterations: Int = 5,
        threshold: BenchmarkThreshold? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: @Sendable () async throws -> Void
    ) async rethrows -> Double {
        var raw: [Double] = []
        raw.reserveCapacity(iterations)
        for _ in 0 ..< iterations {
            let start = CACurrentMediaTime()
            try? await block()
            let elapsed = CACurrentMediaTime() - start
            raw.append(elapsed)
        }
        if raw.count > 2 { raw.removeFirst() }
        let avg = raw.reduce(0, +) / Double(raw.count)

        let effectiveThreshold = threshold ?? activeThresholds[name] ?? .max(.infinity)
        let result = BenchResult(
            name: name,
            metric: .duration,
            value: avg,
            unit: "s",
            threshold: effectiveThreshold,
            iterations: iterations,
            metadata: ["samples": "\(raw.count)", "min": "\(raw.min() ?? 0)", "max": "\(raw.max() ?? 0)"],
            timestamp: Date()
        )
        recordResult(result)
        return avg
    }

    // MARK: - Memory tracking

    /// Returns current resident memory in bytes (approximate).
    public static func currentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }

    /// Executes `block`, returning the delta in resident memory (bytes).
    public func trackMemory(
        name: String,
        threshold: BenchmarkThreshold? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () -> Void
    ) -> Int64 {
        let before = Self.currentMemoryBytes()
        block()
        // Force any deferred dealloc
        autoreleasepool { }
        let after = Self.currentMemoryBytes()
        let delta = Int64(after) - Int64(before)

        let effectiveThreshold = threshold ?? activeThresholds[name] ?? .max(.infinity)
        let result = BenchResult(
            name: name,
            metric: .memory,
            value: Double(delta),
            unit: "bytes",
            threshold: effectiveThreshold,
            iterations: 1,
            metadata: ["before": "\(before)", "after": "\(after)"],
            timestamp: Date()
        )
        recordResult(result)
        return delta
    }

    /// Async variant of `trackMemory`.
    public func trackMemoryAsync(
        name: String,
        threshold: BenchmarkThreshold? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async -> Void
    ) async -> Int64 {
        let before = Self.currentMemoryBytes()
        await block()
        let after = Self.currentMemoryBytes()
        let delta = Int64(after) - Int64(before)

        let effectiveThreshold = threshold ?? activeThresholds[name] ?? .max(.infinity)
        let result = BenchResult(
            name: name,
            metric: .memory,
            value: Double(delta),
            unit: "bytes",
            threshold: effectiveThreshold,
            iterations: 1,
            metadata: ["before": "\(before)", "after": "\(after)"],
            timestamp: Date()
        )
        recordResult(result)
        return delta
    }

    // MARK: - Operation throughput

    /// Measures how many times `block` can execute per second.
    @discardableResult
    public func countOperations(
        name: String,
        duration: TimeInterval = 1.0,
        threshold: BenchmarkThreshold? = nil,
        block: () -> Void
    ) -> Int {
        let start = CACurrentMediaTime()
        var count = 0
        while CACurrentMediaTime() - start < duration {
            block()
            count += 1
        }
        let opsPerSec = Double(count) / duration

        let effectiveThreshold = threshold ?? activeThresholds[name] ?? .min(0)
        let result = BenchResult(
            name: name,
            metric: .throughput,
            value: opsPerSec,
            unit: "ops/s",
            threshold: effectiveThreshold,
            iterations: 1,
            metadata: ["total_ops": "\(count)", "duration_s": "\(duration)"],
            timestamp: Date()
        )
        recordResult(result)
        return count
    }

    // MARK: - Result recording

    public func recordResult(_ result: BenchResult) {
        Self.resultsLock.withLock {
            Self._allResults.append(result)
        }
    }
}

// MARK: - Assert helpers

extension PerformanceTestBase {
    /// Assert that a specific benchmark result passed its threshold.
    public func assertBenchPassed(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let results = Self.allResults.filter { $0.name == name }
        guard let result = results.last else {
            XCTFail("No benchmark result found for '\(name)'", file: file, line: line)
            return
        }
        XCTAssertTrue(result.passed, "Benchmark '\(name)' failed: value=\(result.value) \(result.unit), threshold=\(result.threshold.description)", file: file, line: line)
    }
}

// MARK: - mach_task_basic_info support

private typealias task_info_t = UnsafeMutablePointer<Int32>
private let MACH_TASK_BASIC_INFO = task_flavor_t(20) // MACH_TASK_BASIC_INFO
