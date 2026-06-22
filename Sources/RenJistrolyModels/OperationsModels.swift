// 运营场景模型 (426-435)

import Foundation

// MARK: - 426: 生产开关保护

public struct ProductionSwitch: Codable, Sendable {
    public let name: String
    public var currentValue: Bool
    public let proposedValue: Bool
    public let impact: String
    public let requiresConfirmation: Bool
    public let rollbackProcedure: String?
    public let riskLevel: ProductionSwitchRisk

    public enum ProductionSwitchRisk: String, Codable, Sendable {
        case low
        case medium
        case high
        case critical
    }

    public init(
        name: String,
        currentValue: Bool,
        proposedValue: Bool,
        impact: String,
        requiresConfirmation: Bool = true,
        rollbackProcedure: String? = nil,
        riskLevel: ProductionSwitchRisk = .medium
    ) {
        self.name = name
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.impact = impact
        self.requiresConfirmation = requiresConfirmation
        self.rollbackProcedure = rollbackProcedure
        self.riskLevel = riskLevel
    }
}

// MARK: - 427: 数据导出脱敏

public struct DataExportMaskingRule: Codable, Sendable {
    public let fieldName: String
    public let maskingType: MaskingType
    public let appliesToRoles: [String]

    public enum MaskingType: String, Codable, Sendable {
        case full
        case partial
        case emailMask
        case phoneMask
        case idMask
        case dateRounding
    }

    public init(fieldName: String, maskingType: MaskingType, appliesToRoles: [String] = []) {
        self.fieldName = fieldName
        self.maskingType = maskingType
        self.appliesToRoles = appliesToRoles
    }

    public func apply(to value: String) -> String {
        switch maskingType {
        case .full:
            return String(repeating: "*", count: value.count)
        case .partial:
            guard value.count > 4 else { return String(repeating: "*", count: value.count) }
            let prefix = String(value.prefix(2))
            let suffix = String(value.suffix(2))
            return prefix + String(repeating: "*", count: value.count - 4) + suffix
        case .emailMask:
            guard let atIndex = value.firstIndex(of: "@") else { return value }
            let name = String(value[..<atIndex])
            let domain = String(value[atIndex...])
            guard name.count > 2 else { return "**" + domain }
            return String(name.prefix(2)) + String(repeating: "*", count: name.count - 2) + domain
        case .phoneMask:
            guard value.count >= 7 else { return String(repeating: "*", count: value.count) }
            let prefix = String(value.prefix(3))
            let suffix = String(value.suffix(4))
            return prefix + "****" + suffix
        case .idMask:
            guard value.count >= 4 else { return String(repeating: "*", count: value.count) }
            let prefix = String(value.prefix(1))
            let suffix = String(value.suffix(1))
            return prefix + String(repeating: "*", count: value.count - 2) + suffix
        case .dateRounding:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            if let date = formatter.date(from: value) {
                var components = Calendar.current.dateComponents([.year, .month], from: date)
                components.day = 1
                if let rounded = Calendar.current.date(from: components) {
                    return formatter.string(from: rounded)
                }
            }
            return value
        }
    }
}

// MARK: - 428: Dry-run 预览模式

public struct DryRunPreview: Codable, Sendable {
    public let enabled: Bool
    public let changes: [String]
    public let affectedCount: Int
    public let rollbackSteps: [String]?

    public init(
        enabled: Bool = true,
        changes: [String] = [],
        affectedCount: Int = 0,
        rollbackSteps: [String]? = nil
    ) {
        self.enabled = enabled
        self.changes = changes
        self.affectedCount = affectedCount
        self.rollbackSteps = rollbackSteps
    }
}

// MARK: - 429: 图表 OCR+语义解析

public struct ChartParsedData: Codable, Sendable {
    public let chartType: ChartType
    public let title: String?
    public let dataPoints: [DataPoint]
    public let summary: String
    public let anomalies: [String]

    public enum ChartType: String, Codable, Sendable {
        case line
        case bar
        case pie
        case scatter
        case table
        case unknown
    }

    public struct DataPoint: Codable, Sendable {
        public let label: String
        public let value: Double
        public let series: String?

        public init(label: String, value: Double, series: String? = nil) {
            self.label = label
            self.value = value
            self.series = series
        }
    }

    public init(
        chartType: ChartType = .unknown,
        title: String? = nil,
        dataPoints: [DataPoint] = [],
        summary: String = "",
        anomalies: [String] = []
    ) {
        self.chartType = chartType
        self.title = title
        self.dataPoints = dataPoints
        self.summary = summary
        self.anomalies = anomalies
    }
}

// MARK: - 430: 推送确认流程

public struct PushNotificationRequest: Codable, Sendable {
    public let title: String
    public let body: String
    public let targetSegment: String
    public let estimatedRecipients: Int
    public let scheduledAt: Date?
    public let campaignID: String?
    public let isTestMode: Bool

    public init(
        title: String,
        body: String,
        targetSegment: String,
        estimatedRecipients: Int = 0,
        scheduledAt: Date? = nil,
        campaignID: String? = nil,
        isTestMode: Bool = false
    ) {
        self.title = title
        self.body = body
        self.targetSegment = targetSegment
        self.estimatedRecipients = estimatedRecipients
        self.scheduledAt = scheduledAt
        self.campaignID = campaignID
        self.isTestMode = isTestMode
    }
}

// MARK: - 431: CSV 格式校验

public struct CSVValidationResult: Codable, Sendable {
    public let isValid: Bool
    public let rowCount: Int
    public let columnCount: Int
    public let expectedColumns: [String]
    public let missingColumns: [String]
    public let errors: [CSVRowError]

    public struct CSVRowError: Codable, Sendable, Identifiable {
        public let id: UUID
        public let row: Int
        public let column: String?
        public let message: String
        public let value: String?

        public init(
            id: UUID = UUID(),
            row: Int,
            column: String? = nil,
            message: String,
            value: String? = nil
        ) {
            self.id = id
            self.row = row
            self.column = column
            self.message = message
            self.value = value
        }
    }

    public init(
        isValid: Bool,
        rowCount: Int,
        columnCount: Int,
        expectedColumns: [String] = [],
        missingColumns: [String] = [],
        errors: [CSVRowError] = []
    ) {
        self.isValid = isValid
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.expectedColumns = expectedColumns
        self.missingColumns = missingColumns
        self.errors = errors
    }

    public static func validate(csvContent: String, expectedColumns: [String]) -> CSVValidationResult {
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 1 else {
            return CSVValidationResult(isValid: false, rowCount: 0, columnCount: 0,
                                       expectedColumns: expectedColumns, errors: [.init(row: 0, message: "CSV 内容为空")])
        }
        let headers = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let missingCols = expectedColumns.filter { !headers.contains($0) }
        var errors: [CSVRowError] = []

        for col in expectedColumns where !headers.contains(col) {
            errors.append(.init(row: 1, column: col, message: "缺少必要列: \(col)"))
        }

        for (i, line) in lines.dropFirst().enumerated() {
            let cols = line.components(separatedBy: ",")
            if cols.count != headers.count {
                errors.append(.init(row: i + 2, message: "列数不匹配: 期望 \(headers.count) 列, 实际 \(cols.count) 列"))
            }
        }

        return CSVValidationResult(
            isValid: missingCols.isEmpty && errors.isEmpty,
            rowCount: lines.count - 1,
            columnCount: headers.count,
            expectedColumns: expectedColumns,
            missingColumns: missingCols,
            errors: errors
        )
    }
}

// MARK: - 432: CMS 版本管理

public struct CMSContentVersion: Codable, Sendable, Identifiable {
    public let id: UUID
    public let versionNumber: String
    public let contentID: String
    public let contentTitle: String
    public let updatedAt: Date
    public let updatedBy: String
    public let isPublished: Bool
    public let diffSummary: String

    public init(
        id: UUID = UUID(),
        versionNumber: String,
        contentID: String,
        contentTitle: String,
        updatedAt: Date = Date(),
        updatedBy: String,
        isPublished: Bool = false,
        diffSummary: String = ""
    ) {
        self.id = id
        self.versionNumber = versionNumber
        self.contentID = contentID
        self.contentTitle = contentTitle
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.isPublished = isPublished
        self.diffSummary = diffSummary
    }
}

// MARK: - 435: 基线对比

public struct BaselineComparison: Codable, Sendable {
    public let metricName: String
    public let currentValue: Double
    public let baselineValue: Double
    public let deviationPercent: Double
    public let isAnomaly: Bool
    public let thresholdPercent: Double

    public init(
        metricName: String,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double = 0,
        isAnomaly: Bool = false,
        thresholdPercent: Double = 20
    ) {
        self.metricName = metricName
        self.currentValue = currentValue
        self.baselineValue = baselineValue
        self.deviationPercent = deviationPercent
        self.isAnomaly = isAnomaly
        self.thresholdPercent = thresholdPercent
    }

    public static func compute(
        metricName: String,
        currentValue: Double,
        baselineValue: Double,
        thresholdPercent: Double = 20
    ) -> BaselineComparison {
        let deviation: Double
        if baselineValue > 0 {
            deviation = (currentValue - baselineValue) / baselineValue * 100
        } else if currentValue > 0 {
            deviation = 100
        } else {
            deviation = 0
        }
        let isAnomaly = abs(deviation) > thresholdPercent
        return BaselineComparison(
            metricName: metricName,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviation,
            isAnomaly: isAnomaly,
            thresholdPercent: thresholdPercent
        )
    }
}
