import Foundation

// MARK: - Benchmark Report Generator

/// Generates structured reports from `PerformanceTestBase.BenchResult` data.
///
/// Usage:
/// ```swift
/// let report = BenchReport(results: PerformanceTestBase.allResults)
/// print(report.markdownSummary())
/// try report.writeHTML(to: "/tmp/bench-report.html")
/// ```
public struct BenchReport: Sendable {

    public let results: [PerformanceTestBase.BenchResult]
    public let generatedAt: Date
    public let baseline: [String: Double]?

    public init(
        results: [PerformanceTestBase.BenchResult],
        generatedAt: Date = Date(),
        baseline: [String: Double]? = nil
    ) {
        self.results = results
        self.generatedAt = generatedAt
        self.baseline = baseline
    }

    // MARK: - Summary stats

    public var totalCount: Int { results.count }
    public var passedCount: Int { results.filter(\.passed).count }
    public var failedCount: Int { results.filter { !$0.passed }.count }

    public var passRate: Double {
        guard totalCount > 0 else { return 1.0 }
        return Double(passedCount) / Double(totalCount)
    }

    // MARK: - Markdown report

    /// Returns a full Markdown report with summary, results table, and failure details.
    public func markdownSummary() -> String {
        var lines: [String] = []
        lines.append("# RenJistroly Performance Benchmark Report")
        lines.append("")
        lines.append("**Generated**: \(isoFormatter.string(from: generatedAt))")
        lines.append("**Tests**: \(totalCount) total, \(passedCount) passed, \(failedCount) failed")
        lines.append("**Pass rate**: \(String(format: "%.1f", passRate * 100))%")
        lines.append("")

        if failedCount > 0 {
            lines.append("## Failures")
            lines.append("")
            for result in results where !result.passed {
                let baselineStr = baseline.map { b in
                    ", baseline: \(String(format: "%.4f", b))"
                } ?? ""
                lines.append("- **\(result.name)**: \(formatValue(result)) \(result.unit) (threshold: \(result.threshold.description)\(baselineStr))")
            }
            lines.append("")
        }

        lines.append("## Results by Metric")
        lines.append("")

        let grouped = Dictionary(grouping: results, by: \.metric)
        for (metric, group) in grouped.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            lines.append("### \(metric.rawValue.capitalized)")
            lines.append("")
            lines.append(resultTable(for: group))
            lines.append("")
        }

        if baseline != nil {
            lines.append("## Baseline Comparison")
            lines.append("")
            lines.append(baselineComparisonTable())
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    /// Returns a Markdown table for a set of results.
    private func resultTable(for results: [PerformanceTestBase.BenchResult]) -> String {
        var lines: [String] = []
        lines.append("| Name | Value | Unit | Threshold | Passed |")
        lines.append("|------|-------|------|-----------|--------|")

        for result in results.sorted(by: { $0.name < $1.name }) {
            let status = result.passed ? ":white_check_mark:" : ":x:"
            lines.append("| \(result.name) | \(formatValue(result)) | \(result.unit) | \(result.threshold.description) | \(status) |")
        }
        return lines.joined(separator: "\n")
    }

    /// Returns a comparison table against baseline values.
    private func baselineComparisonTable() -> String {
        var lines: [String] = []
        lines.append("| Name | Current | Baseline | Delta | % Change |")
        lines.append("|------|---------|----------|-------|----------|")

        for result in results.sorted(by: { $0.name < $1.name }) {
            guard let baseline = baseline, let base = baseline[result.name] else { continue }
            let current = result.value
            let delta = current - base
            let pct = base != 0 ? (delta / base) * 100 : 0
            let arrow: String
            if result.metric == .duration || result.metric == .memory {
                arrow = delta > 0 ? ":arrow_up:" : (delta < 0 ? ":arrow_down:" : ":minus:")
            } else {
                // throughput — bigger is better
                arrow = delta > 0 ? ":arrow_down:" : (delta < 0 ? ":arrow_up:" : ":minus:")
            }
            lines.append("| \(result.name) | \(formatValue(result)) | \(String(format: "%.4f", base)) | \(String(format: "%+.4f", delta)) | \(arrow) \(String(format: "%+.1f", pct))% |")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - HTML report

    /// Generates a standalone HTML report.
    public func htmlReport() -> String {
        let passedPct = String(format: "%.1f", passRate * 100)
        let failedRows = results.filter { !$0.passed }.map { result in
            """
            <tr class="failed">
                <td>\(escaped: result.name)</td>
                <td>\(formatValue(result))</td>
                <td>\(result.unit)</td>
                <td>\(escaped: result.threshold.description)</td>
            </tr>
            """
        }.joined(separator: "\n")

        let allRows = results.sorted(by: { $0.name < $1.name }).map { result in
            let cls = result.passed ? "passed" : "failed"
            let baselineStr = baseline.flatMap { $0[result.name] }.map { base in
                let delta = result.value - base
                let pct = base != 0 ? (delta / base) * 100 : 0
                return "<td>\(String(format: "%.4f", base))</td><td>\(String(format: "%+.1f", pct))%</td>"
            } ?? "<td colspan='2'>—</td>"
            return """
            <tr class="\(cls)">
                <td>\(escaped: result.name)</td>
                <td>\(formatValue(result))</td>
                <td>\(result.unit)</td>
                <td>\(escaped: result.threshold.description)</td>
                <td>\(result.passed ? "PASS" : "FAIL")</td>
                \(baselineStr)
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <title>RenJistroly Performance Benchmark Report</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 1200px; margin: 2em auto; padding: 0 1em; color: #1d1d1f; background: #f5f5f7; }
            h1 { font-size: 1.8em; font-weight: 600; }
            .summary { background: #fff; border-radius: 12px; padding: 1.5em; margin: 1em 0; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
            .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 1em; }
            .stat { text-align: center; }
            .stat-value { font-size: 2em; font-weight: 700; }
            .stat-label { font-size: 0.85em; color: #6e6e73; }
            .stat.passed .stat-value { color: #30b158; }
            .stat.failed .stat-value { color: #ff3b30; }
            table { width: 100%; border-collapse: collapse; margin: 1em 0; background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
            th { background: #f5f5f7; padding: 0.75em 1em; text-align: left; font-weight: 600; font-size: 0.85em; text-transform: uppercase; letter-spacing: 0.05em; color: #6e6e73; border-bottom: 1px solid #d2d2d7; }
            td { padding: 0.75em 1em; border-bottom: 1px solid #ececf0; }
            tr:last-child td { border-bottom: none; }
            .passed td { }
            .failed td { background: #fff2f0; }
            .failed .status { color: #ff3b30; font-weight: 600; }
            .timestamp { color: #6e6e73; font-size: 0.85em; }
        </style>
        </head>
        <body>
            <h1>RenJistroly Performance Benchmark Report</h1>
            <p class="timestamp">Generated: \(isoFormatter.string(from: generatedAt))</p>

            <div class="summary">
                <div class="summary-grid">
                    <div class="stat passed">
                        <div class="stat-value">\(passedCount)</div>
                        <div class="stat-label">Passed</div>
                    </div>
                    <div class="stat\(failedCount > 0 ? " failed" : "")">
                        <div class="stat-value">\(failedCount)</div>
                        <div class="stat-label">Failed</div>
                    </div>
                    <div class="stat">
                        <div class="stat-value">\(passedPct)%</div>
                        <div class="stat-label">Pass Rate</div>
                    </div>
                    <div class="stat">
                        <div class="stat-value">\(totalCount)</div>
                        <div class="stat-label">Total Tests</div>
                    </div>
                </div>
            </div>

            \(failedCount > 0 ? """
            <h2>Failures</h2>
            <table>
                <tr><th>Name</th><th>Value</th><th>Unit</th><th>Threshold</th></tr>
                \(failedRows)
            </table>
            """ : "<p>All benchmarks passed.</p>")"

            <h2>All Results</h2>
            <table>
                <tr>
                    <th>Name</th>
                    <th>Value</th>
                    <th>Unit</th>
                    <th>Threshold</th>
                    <th>Status</th>
                    \(baseline != nil ? "<th>Baseline</th><th>% Change</th>" : "")
                </tr>
                \(allRows)
            </table>

            <p class="timestamp">Report generated by RenJistroly Performance Test Suite</p>
        </body>
        </html>
        """
    }

    /// Writes an HTML report to the given file path.
    public func writeHTML(to path: String) throws {
        try htmlReport().write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Writes a Markdown report to the given file path.
    public func writeMarkdown(to path: String) throws {
        try markdownSummary().write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - JSON export

    /// Returns the results as a JSON-encoded `Data` blob for archival / CI.
    public func jsonExport() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(ExportPayload(
            generatedAt: generatedAt,
            results: results.map(ExportResult.init),
            baseline: baseline
        ))
    }

    // MARK: - Helpers

    private func formatValue(_ result: PerformanceTestBase.BenchResult) -> String {
        switch result.metric {
        case .duration:
            if result.value < 1 {
                return String(format: "%.2f ms", result.value * 1000)
            }
            return String(format: "%.3f s", result.value)
        case .memory:
            if abs(result.value) < 1024 {
                return String(format: "%.0f B", result.value)
            } else if abs(result.value) < 1024 * 1024 {
                return String(format: "%.1f KB", result.value / 1024)
            }
            return String(format: "%.1f MB", result.value / (1024 * 1024))
        case .throughput:
            return String(format: "%.0f", result.value)
        case .count:
            return String(format: "%.0f", result.value)
        }
    }
}

// MARK: - JSON export model

private struct ExportPayload: Codable, Sendable {
    let generatedAt: Date
    let results: [ExportResult]
    let baseline: [String: Double]?
}

private struct ExportResult: Codable, Sendable {
    let name: String
    let metric: String
    let value: Double
    let unit: String
    let threshold: String
    let passed: Bool
    let iterations: Int
    let metadata: [String: String]
    let timestamp: Date

    init(_ r: PerformanceTestBase.BenchResult) {
        name = r.name
        metric = r.metric.rawValue
        value = r.value
        unit = r.unit
        threshold = r.threshold.description
        passed = r.passed
        iterations = r.iterations
        metadata = r.metadata
        timestamp = r.timestamp
    }
}

// MARK: - Formatters

private nonisolated(unsafe) let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - HTML escaping helper

// swift-format-ignore
extension String.StringInterpolation {
    mutating func appendInterpolation(escaped value: String) {
        appendLiteral(value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        )
    }
}
