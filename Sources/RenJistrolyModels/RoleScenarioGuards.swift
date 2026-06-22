import Foundation

// MARK: - Finance Scenario Guards (436-445)

// 436. OCR 数字校验和纠错
public struct OCRDigitValidator: Sendable, Codable, Equatable {
    public var rawText: String
    public var correctedText: String?
    public var corrections: [OCRCorrection]
    public var confidence: Double

    public init(rawText: String, correctedText: String? = nil, corrections: [OCRCorrection] = [], confidence: Double = 1.0) {
        self.rawText = rawText
        self.correctedText = correctedText
        self.corrections = corrections
        self.confidence = confidence
    }

    public mutating func validate() {
        let digits = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".,-"))
        var result = rawText
        var detected: [OCRCorrection] = []
        let commonMistakes: [(Character, Character)] = [
            ("O", "0"), ("o", "0"), ("I", "1"), ("l", "1"), ("Z", "2"),
            ("S", "5"), ("s", "5"), ("B", "8"), ("g", "9"), ("q", "9"),
        ]
        for index in result.indices {
            guard let (_, correct) = commonMistakes.first(where: { $0.0 == result[index] }) else {
                continue
            }

            let previous = index == result.startIndex ? nil : result[result.index(before: index)]
            let nextIndex = result.index(after: index)
            let next = nextIndex == result.endIndex ? nil : result[nextIndex]
            let nearDigit = previous?.isNumber == true || next?.isNumber == true

            if nearDigit {
                detected.append(OCRCorrection(from: String(result[index]), to: String(correct), count: 1))
                result.replaceSubrange(index...index, with: String(correct))
            }
        }
        let numericChars = result.filter { String($0).rangeOfCharacter(from: digits) != nil }
        confidence = Double(numericChars.count) / Double(max(result.count, 1))
        correctedText = result
        corrections = detected
    }

    public var isValid: Bool { confidence >= 0.7 }
}

public struct OCRCorrection: Sendable, Codable, Equatable {
    public var from: String
    public var to: String
    public var count: Int
    public init(from: String, to: String, count: Int) {
        self.from = from
        self.to = to
        self.count = count
    }
}

// 437. 金额验证
public struct AmountValidator: Sendable, Codable, Equatable {
    public var detectedAmount: Double
    public var expectedRange: ClosedRange<Double>
    public var currency: String

    public init(detectedAmount: Double, expectedRange: ClosedRange<Double>, currency: String = "CNY") {
        self.detectedAmount = detectedAmount
        self.expectedRange = expectedRange
        self.currency = currency
    }

    public var isInRange: Bool { expectedRange.contains(detectedAmount) }
    public var deviation: Double { detectedAmount - expectedRange.lowerBound }

    public func formatted() -> String {
        let status = isInRange ? "通过" : "超出范围"
        return "[\(currency)] \(detectedAmount) \(status) (期望: \(expectedRange.lowerBound)-\(expectedRange.upperBound))"
    }
}

// 438. 敏感数据保护
public struct SensitiveDataProtector: Sendable, Codable, Equatable {
    public enum DataType: String, Sendable, Codable, CaseIterable {
        case bankAccount, creditCard, idNumber, phoneNumber, address, transaction
    }

    public var detectedTypes: Set<DataType>
    public var redactedFields: [String]
    public var isProtected: Bool

    public init(detectedTypes: Set<DataType> = [], redactedFields: [String] = [], isProtected: Bool = false) {
        self.detectedTypes = detectedTypes
        self.redactedFields = redactedFields
        self.isProtected = isProtected
    }

    public mutating func analyze(_ text: String) {
        if text.range(of: #"\d{16,19}"#, options: .regularExpression) != nil {
            detectedTypes.insert(.creditCard)
        }
        if text.range(of: #"\d{15,18}"#, options: .regularExpression) != nil {
            detectedTypes.insert(.idNumber)
        }
        if text.range(of: #"\d{3}-\d{4,8}"#, options: .regularExpression) != nil {
            detectedTypes.insert(.bankAccount)
        }
        if text.range(of: #"1[3-9]\d{9}"#, options: .regularExpression) != nil {
            detectedTypes.insert(.phoneNumber)
        }
        if !text.filter({ $0 == "★" || $0 == "*" }).isEmpty {
            redactedFields = detectedTypes.map { "\($0.rawValue):已脱敏" }
            isProtected = true
        }
    }
}

// 439. 付款审批流
public struct PaymentApprovalFlow: Sendable, Codable, Equatable {
    public enum ApprovalLevel: String, Sendable, Codable {
        case under1000, under10000, under100000, above100000
    }

    public var amount: Double
    public var requiredLevel: ApprovalLevel
    public var approvedBy: [String]
    public var requiresDoubleConfirmation: Bool

    public init(amount: Double, approvedBy: [String] = []) {
        self.amount = amount
        self.approvedBy = approvedBy
        switch amount {
        case ..<1000: requiredLevel = .under1000
        case ..<10000: requiredLevel = .under10000
        case ..<100000: requiredLevel = .under100000
        default: requiredLevel = .above100000
        }
        requiresDoubleConfirmation = amount >= 10000
    }

    public var needsMoreApprovals: Bool {
        switch requiredLevel {
        case .under1000: return approvedBy.count < 1
        case .under10000: return approvedBy.count < 2
        case .under100000: return approvedBy.count < 3
        case .above100000: return approvedBy.count < 4
        }
    }

    public var summary: String {
        "金额: \(amount), 级别: \(requiredLevel), 已批准: \(approvedBy.count)人, 需双确认: \(requiresDoubleConfirmation)"
    }
}

// 440. Excel 公式感知
public struct ExcelFormulaAwareness: Sendable, Codable, Equatable {
    public var detectedFormulas: [String]
    public var formulaCount: Int { detectedFormulas.count }
    public var hasDetectedFormulas: Bool { !detectedFormulas.isEmpty }

    public init(detectedFormulas: [String] = []) {
        self.detectedFormulas = detectedFormulas
    }

    public static let formulaPatterns: [String] = [
        "=SUM(", "=AVERAGE(", "=IF(", "=VLOOKUP(", "=INDEX(", "=MATCH(",
        "=COUNT(", "=MAX(", "=MIN(", "=ROUND(", "=CONCATENATE(", "=TEXT(",
        "=DATE(", "=NOW(", "=TODAY(", "=SUMIF(", "=COUNTIF(", "=XLOOKUP(",
        "=LET(", "=LAMBDA(", "=FILTER(", "=SORT(", "=UNIQUE(",
    ]

    public mutating func analyze(_ text: String) {
        detectedFormulas = Self.formulaPatterns.filter { text.localizedCaseInsensitiveContains($0) }
    }
}

// 441. Excel 格式保护
public struct ExcelFormatProtector: Sendable, Codable, Equatable {
    public var protectedFormats: Set<String>
    public var originalFormatSnapshot: [String: String]
    public var isFormatPreserved: Bool

    public init(protectedFormats: Set<String> = [], originalFormatSnapshot: [String: String] = [:], isFormatPreserved: Bool = true) {
        self.protectedFormats = protectedFormats
        self.originalFormatSnapshot = originalFormatSnapshot
        self.isFormatPreserved = isFormatPreserved
    }

    public mutating func preserveFormat(cell: String, format: String) {
        originalFormatSnapshot[cell] = format
        protectedFormats.insert(cell)
    }

    public func formatChanged(cell: String, newFormat: String) -> Bool {
        guard let original = originalFormatSnapshot[cell] else { return false }
        return original != newFormat && protectedFormats.contains(cell)
    }
}

// 442. 税务信息隔离
public struct TaxInfoIsolator: Sendable, Codable, Equatable {
    public var allowedRecipients: [String]
    public var isTaxData: Bool
    public var isolationLevel: IsolationLevel

    public enum IsolationLevel: String, Sendable, Codable {
        case none, masked, fullyIsolated
    }

    public init(allowedRecipients: [String] = [], isTaxData: Bool = false, isolationLevel: IsolationLevel = .none) {
        self.allowedRecipients = allowedRecipients
        self.isTaxData = isTaxData
        self.isolationLevel = isolationLevel
    }

    public mutating func classify(_ text: String) {
        let taxKeywords = ["税务", "tax", "个人所得税", "增值税", "企业所得税", "发票", "invoice", "税号", "纳税人"]
        isTaxData = taxKeywords.contains { text.localizedCaseInsensitiveContains($0) }
        isolationLevel = isTaxData ? .masked : .none
    }

    public func canShare(with recipient: String) -> Bool {
        guard isTaxData else { return true }
        return allowedRecipients.contains { recipient.localizedCaseInsensitiveContains($0) }
    }
}

// 443. 敏感剪贴板管理
public struct SensitiveClipboardManager: Sendable, Codable, Equatable {
    public var lastCopyContentType: ClipboardContentType
    public var isSensitive: Bool
    public var autoClearAfter: TimeInterval

    public enum ClipboardContentType: String, Sendable, Codable, CaseIterable {
        case normal, accountNumber, password, idCard, financialData, taxInfo
    }

    public init(lastCopyContentType: ClipboardContentType = .normal, isSensitive: Bool = false, autoClearAfter: TimeInterval = 30) {
        self.lastCopyContentType = lastCopyContentType
        self.isSensitive = isSensitive
        self.autoClearAfter = autoClearAfter
    }

    public mutating func classify(_ text: String) {
        if text.range(of: #"^\d{16,20}$"#, options: .regularExpression) != nil {
            lastCopyContentType = .accountNumber; isSensitive = true
        } else if text.range(of: #"^[A-Za-z0-9!@#$%^&*]{8,}$"#, options: .regularExpression) != nil {
            lastCopyContentType = .password; isSensitive = true
        } else if text.range(of: #"\d{18}"#, options: .regularExpression) != nil {
            lastCopyContentType = .idCard; isSensitive = true
        } else {
            lastCopyContentType = .normal; isSensitive = false
        }
    }

    public var warningMessage: String? {
        isSensitive ? "已复制敏感信息 (\(lastCopyContentType.rawValue))，\(Int(autoClearAfter))秒后自动清除" : nil
    }
}

// 444. 对账误差阈值
public struct ReconciliationErrorThreshold: Sendable, Codable, Equatable {
    public var expectedAmount: Double
    public var actualAmount: Double
    public var threshold: Double

    public init(expectedAmount: Double, actualAmount: Double, threshold: Double = 0.01) {
        self.expectedAmount = expectedAmount
        self.actualAmount = actualAmount
        self.threshold = threshold
    }

    public var difference: Double { abs(expectedAmount - actualAmount) }
    public var isWithinThreshold: Bool { difference <= threshold }
    public var deviationPercent: Double {
        guard expectedAmount != 0 else { return difference == 0 ? 0 : 100 }
        return (difference / abs(expectedAmount)) * 100
    }

    public var formatted: String {
        let status = isWithinThreshold ? "通过" : "超出阈值"
        return "期望: \(expectedAmount), 实际: \(actualAmount), 差异: \(difference), 阈值: \(threshold), \(status)"
    }
}

// 445. 表单提交确认
public struct FormSubmitConfirmation: Sendable, Codable, Equatable {
    public var fieldCount: Int
    public var requiresFinalCheck: Bool
    public var isConfirmed: Bool

    public init(fieldCount: Int, requiresFinalCheck: Bool = true, isConfirmed: Bool = false) {
        self.fieldCount = fieldCount
        self.requiresFinalCheck = requiresFinalCheck
        self.isConfirmed = isConfirmed
    }

    public var summary: String {
        guard requiresFinalCheck else { return "无需确认" }
        return "共 \(fieldCount) 个字段，\(isConfirmed ? "已最终确认" : "等待最终确认")"
    }
}

// MARK: - HR Scenario Guards (446-455)

// 446. 简历数据脱敏
public struct ResumeDataMasker: Sendable, Codable, Equatable {
    public var maskedFields: Set<ResumeField>
    public var isMasked: Bool

    public enum ResumeField: String, Sendable, Codable, CaseIterable {
        case name, phone, email, address, idNumber, wechat, socialAccount
    }

    public init(maskedFields: Set<ResumeField> = [], isMasked: Bool = false) {
        self.maskedFields = maskedFields
        self.isMasked = isMasked
    }

    public static func mask(_ text: String, fields: Set<ResumeField>) -> String {
        var result = text
        if fields.contains(.name) {
            result = result.replacingOccurrences(of: #"\p{Lu}{2,4}"#, with: "***", options: .regularExpression)
        }
        if fields.contains(.phone) {
            result = result.replacingOccurrences(of: #"1[3-9]\d{9}"#, with: "1**********", options: .regularExpression)
        }
        if fields.contains(.email) {
            result = result.replacingOccurrences(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, with: "***@***.***", options: .regularExpression)
        }
        if fields.contains(.idNumber) {
            result = result.replacingOccurrences(of: #"\d{18}[Xx]?"#, with: "******************", options: .regularExpression)
        }
        return result
    }

    public mutating func applyMask(to text: String) -> String {
        isMasked = true
        return Self.mask(text, fields: maskedFields.isEmpty ? Set(ResumeField.allCases) : maskedFields)
    }
}

// 447. offer 薪资验证
public struct OfferSalaryValidator: Sendable, Codable, Equatable {
    public var baseSalary: Double
    public var currency: String
    public var bandMin: Double
    public var bandMax: Double
    public var bonusPercent: Double

    public init(baseSalary: Double, currency: String = "CNY", bandMin: Double, bandMax: Double, bonusPercent: Double = 0) {
        self.baseSalary = baseSalary
        self.currency = currency
        self.bandMin = bandMin
        self.bandMax = bandMax
        self.bonusPercent = bonusPercent
    }

    public var isWithinBand: Bool { baseSalary >= bandMin && baseSalary <= bandMax }
    public var totalCompensation: Double { baseSalary * (1 + bonusPercent / 100) }

    public var summary: String {
        let status = isWithinBand ? "合规" : "超出薪资带宽"
        return "\(currency) \(baseSalary)/月 (\(status), 带宽: \(bandMin)-\(bandMax))"
    }
}

// 448. 候选人确认
public struct CandidateConfirmer: Sendable, Codable, Equatable {
    public var candidateName: String
    public var position: String
    public var confirmedBy: [String]
    public var isConfirmed: Bool

    public init(candidateName: String, position: String, confirmedBy: [String] = [], isConfirmed: Bool = false) {
        self.candidateName = candidateName
        self.position = position
        self.confirmedBy = confirmedBy
        self.isConfirmed = isConfirmed
    }

    public var needsConfirmation: Bool { !isConfirmed }
    public var summary: String {
        isConfirmed ? "候选人 \(candidateName)（\(position)）已确认" : "候选人 \(candidateName)（\(position)）待确认"
    }
}

// 449. HR 权限边界
public struct HRPermissionBoundary: Sendable, Codable, Equatable {
    public var allowedOperations: Set<HROperation>
    public var restrictedOperations: [HROperation]

    public enum HROperation: String, Sendable, Codable, CaseIterable {
        case viewPersonalInfo, editSalary, editContract, viewMedicalHistory,
             terminateEmployee, approveLeave, viewDisciplinary, editPerformance
    }

    public init(allowedOperations: Set<HROperation> = Set(HROperation.allCases), restrictedOperations: [HROperation] = []) {
        self.allowedOperations = allowedOperations
        self.restrictedOperations = restrictedOperations
    }

    public func canPerform(_ operation: HROperation) -> Bool {
        !restrictedOperations.contains(operation)
    }
}

// 450. 合规语气检查
public struct ComplianceToneChecker: Sendable, Codable, Equatable {
    public var detectedIssues: [ToneIssue]
    public var isCompliant: Bool { detectedIssues.isEmpty }

    public struct ToneIssue: Sendable, Codable, Equatable {
        public var phrase: String
        public var severity: Severity
        public var suggestion: String

        public enum Severity: String, Sendable, Codable { case warning, violation }

        public init(phrase: String, severity: Severity, suggestion: String) {
            self.phrase = phrase
            self.severity = severity
            self.suggestion = suggestion
        }
    }

    public init(detectedIssues: [ToneIssue] = []) {
        self.detectedIssues = detectedIssues
    }

    public mutating func analyze(_ text: String) {
        let patterns: [(String, ToneIssue.Severity, String)] = [
            ("你总是", .warning, "避免绝对化表述"),
            ("你从来不", .warning, "避免绝对化表述"),
            ("太差了", .violation, "用建设性反馈替代"),
            ("很差", .violation, "用具体数据说明问题"),
            ("没有价值", .violation, "用事实陈述"),
            ("垃圾", .violation, "违反职业操守"),
            ("废物", .violation, "违反职业操守"),
            ("你应该", .warning, "用建议性语气"),
            ("你必须", .warning, "用建议性语气"),
            ("我不管", .violation, "缺乏专业态度"),
        ]
        for (phrase, severity, suggestion) in patterns {
            if text.localizedCaseInsensitiveContains(phrase) {
                detectedIssues.append(ToneIssue(phrase: phrase, severity: severity, suggestion: suggestion))
            }
        }
    }
}

// 451. 离职流程风控
public struct ResignationRiskController: Sendable, Codable, Equatable {
    public var riskLevel: RiskLevel
    public var requiredSteps: [String]
    public var completedSteps: Set<String>

    public enum RiskLevel: String, Sendable, Codable {
        case low, medium, high, critical
    }

    public init(riskLevel: RiskLevel = .low, requiredSteps: [String] = ResignationRiskController.defaultSteps, completedSteps: Set<String> = []) {
        self.riskLevel = riskLevel
        self.requiredSteps = requiredSteps
        self.completedSteps = completedSteps
    }

    public static let defaultSteps: [String] = [
        "离职面谈", "资产归还", "知识交接", "系统权限回收",
        "薪资结算", "离职证明", "社保转移", "竞业协议确认",
    ]

    public var progress: Double { Double(completedSteps.count) / Double(requiredSteps.count) }
    public var isComplete: Bool { completedSteps.count >= requiredSteps.count }
    public var warningMessage: String? {
        riskLevel == .critical ? "高风险离职，需HRBP和法务双重确认" : nil
    }
}

// 452. 隐私边界
public struct PrivacyBoundaryGuard: Sendable, Codable, Equatable {
    public var detectedPII: Set<PIIField>
    public var allowedPurposes: [String]

    public enum PIIField: String, Sendable, Codable, CaseIterable {
        case chatHistory, medicalRecord, salaryInfo, performanceReview,
             disciplinaryRecord, familyInfo, locationHistory
    }

    public init(detectedPII: Set<PIIField> = [], allowedPurposes: [String] = []) {
        self.detectedPII = detectedPII
        self.allowedPurposes = allowedPurposes
    }

    public mutating func analyze(_ text: String, purpose: String) -> Bool {
        let piiPatterns: [(PIIField, String)] = [
            (.chatHistory, "聊天记录|聊天|对话|消息记录"),
            (.medicalRecord, "病历|体检|诊断|医疗"),
            (.salaryInfo, "薪资|工资|薪酬|待遇"),
            (.performanceReview, "绩效|考核|KPI|评估"),
            (.disciplinaryRecord, "处分|警告|处罚|违纪"),
            (.familyInfo, "家庭|亲属|家属|婚姻"),
            (.locationHistory, "位置|行程|定位|轨迹"),
        ]
        for (field, pattern) in piiPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                detectedPII.insert(field)
            }
        }
        return !detectedPII.isEmpty
    }
}

// 453. 合同审查流程
public struct ContractReviewFlow: Sendable, Codable, Equatable {
    public var requiresLegalReview: Bool
    public var legalReviewCompleted: Bool
    public var reviewNotes: [String]

    public init(requiresLegalReview: Bool = true, legalReviewCompleted: Bool = false, reviewNotes: [String] = []) {
        self.requiresLegalReview = requiresLegalReview
        self.legalReviewCompleted = legalReviewCompleted
        self.reviewNotes = reviewNotes
    }

    public var canProceed: Bool { !requiresLegalReview || legalReviewCompleted }
    public var summary: String {
        if !requiresLegalReview { return "无需法务审查" }
        return legalReviewCompleted ? "法务审查已完成" : "等待法务审查"
    }
}

// 454. 批量发送确认
public struct BatchSendConfirmer: Sendable, Codable, Equatable {
    public var totalRecipients: Int
    public var confirmedRecipients: [String]
    public var requiresDoubleCheck: Bool

    public init(totalRecipients: Int, confirmedRecipients: [String] = [], requiresDoubleCheck: Bool = true) {
        self.totalRecipients = totalRecipients
        self.confirmedRecipients = confirmedRecipients
        self.requiresDoubleCheck = requiresDoubleCheck
    }

    public var allConfirmed: Bool { confirmedRecipients.count == totalRecipients }
    public var progress: Double { totalRecipients > 0 ? Double(confirmedRecipients.count) / Double(totalRecipients) : 1.0 }
    public var warningMessage: String? {
        guard requiresDoubleCheck else { return nil }
        return totalRecipients > 10 ? "批量发送 \(totalRecipients) 人，请逐人确认收件人" : nil
    }
}

// 455. 字段验证
public struct FieldValidator: Sendable, Codable, Equatable {
    public var fieldRules: [String: FieldRule]
    public var validationErrors: [String: String]

    public struct FieldRule: Sendable, Codable, Equatable {
        public var required: Bool
        public var minLength: Int?
        public var maxLength: Int?
        public var pattern: String?
        public var customValidator: String?

        public init(required: Bool = false, minLength: Int? = nil, maxLength: Int? = nil, pattern: String? = nil, customValidator: String? = nil) {
            self.required = required
            self.minLength = minLength
            self.maxLength = maxLength
            self.pattern = pattern
            self.customValidator = customValidator
        }
    }

    public init(fieldRules: [String: FieldRule] = [:], validationErrors: [String: String] = [:]) {
        self.fieldRules = fieldRules
        self.validationErrors = validationErrors
    }

    public mutating func validate(field: String, value: String) -> Bool {
        guard let rule = fieldRules[field] else { return true }
        if rule.required && value.isEmpty {
            validationErrors[field] = "\(field) 为必填项"
            return false
        }
        if let min = rule.minLength, value.count < min {
            validationErrors[field] = "\(field) 至少 \(min) 个字符"
            return false
        }
        if let max = rule.maxLength, value.count > max {
            validationErrors[field] = "\(field) 最多 \(max) 个字符"
            return false
        }
        if let pattern = rule.pattern, let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            if regex.firstMatch(in: value, range: range) == nil {
                validationErrors[field] = "\(field) 格式不正确"
                return false
            }
        }
        return true
    }

    public var isValid: Bool { validationErrors.isEmpty }
}

// MARK: - Manager Scenario Guards (456-465)

// 456. 进度真实性
public struct ProgressAuthenticityChecker: Sendable, Codable, Equatable {
    public var reportedProgress: Double
    public var actualProgress: Double
    public var lastVerifiedDate: Date?
    public var verificationSources: [String]

    public init(reportedProgress: Double = 0, actualProgress: Double = 0, lastVerifiedDate: Date? = nil, verificationSources: [String] = []) {
        self.reportedProgress = reportedProgress
        self.actualProgress = actualProgress
        self.lastVerifiedDate = lastVerifiedDate
        self.verificationSources = verificationSources
    }

    public var deviation: Double { reportedProgress - actualProgress }
    public var isAuthentic: Bool { abs(deviation) <= 10 }
    public var warningMessage: String? {
        guard deviation > 10 else { return nil }
        return "报告进度 \(reportedProgress)% vs 实际 \(actualProgress)%，偏差 \(deviation)%，待确认"
    }
}

// 457. 图表趋势解读
public struct ChartTrendInterpreter: Sendable, Codable, Equatable {
    public var dataPoints: [ChartDataPoint]
    public var detectedTrend: TrendDirection
    public var confidence: Double

    public struct ChartDataPoint: Sendable, Codable, Equatable {
        public var label: String
        public var value: Double
        public init(label: String, value: Double) {
            self.label = label
            self.value = value
        }
    }

    public enum TrendDirection: String, Sendable, Codable {
        case upward, downward, stable, volatile, cyclical
    }

    public init(dataPoints: [ChartDataPoint] = [], detectedTrend: TrendDirection = .stable, confidence: Double = 0) {
        self.dataPoints = dataPoints
        self.detectedTrend = detectedTrend
        self.confidence = confidence
    }

    public mutating func analyze() {
        guard dataPoints.count >= 2 else { detectedTrend = .stable; confidence = 0; return }
        let values = dataPoints.map(\.value)
        let diffs = zip(values, values.dropFirst()).map { $1 - $0 }
        let avgDiff = diffs.reduce(0, +) / Double(diffs.count)
        let variance = diffs.map { ($0 - avgDiff) * ($0 - avgDiff) }.reduce(0, +) / Double(diffs.count)
        let stdDev = sqrt(variance)
        let positiveCount = diffs.filter { $0 > 0 }.count
        let negativeCount = diffs.filter { $0 < 0 }.count
        if abs(avgDiff) / max(abs(values.first ?? 1), 0.01) < 0.02 {
            detectedTrend = .stable
        } else if positiveCount > diffs.count * 2 / 3 {
            detectedTrend = .upward
        } else if negativeCount > diffs.count * 2 / 3 {
            detectedTrend = .downward
        } else if stdDev / max(abs(avgDiff), 0.01) > 2 {
            detectedTrend = .volatile
        } else {
            detectedTrend = .stable
        }
        confidence = min(1.0, Double(dataPoints.count) / 10.0)
    }
}

// 458. 周报引用溯源
public struct WeeklyReportCitationTracer: Sendable, Codable, Equatable {
    public var citations: [Citation]
    public var isVerified: Bool

    public struct Citation: Sendable, Codable, Equatable {
        public var claim: String
        public var source: String
        public var isVerified: Bool

        public init(claim: String, source: String, isVerified: Bool = false) {
            self.claim = claim
            self.source = source
            self.isVerified = isVerified
        }
    }

    public init(citations: [Citation] = [], isVerified: Bool = false) {
        self.citations = citations
        self.isVerified = isVerified
    }

    public var unverifiedCount: Int { citations.filter { !$0.isVerified }.count }
    public var verifiedCount: Int { citations.filter(\.isVerified).count }
}

// 459. 会议冲突检测
public struct MeetingConflictDetector: Sendable, Codable, Equatable {
    public var meetings: [Meeting]
    public var conflicts: [Conflict]

    public struct Meeting: Sendable, Codable, Equatable {
        public var title: String
        public var startTime: Date
        public var endTime: Date
        public var attendees: [String]

        public init(title: String, startTime: Date, endTime: Date, attendees: [String] = []) {
            self.title = title
            self.startTime = startTime
            self.endTime = endTime
            self.attendees = attendees
        }
    }

    public struct Conflict: Sendable, Codable, Equatable {
        public var meetingA: String
        public var meetingB: String
        public var description: String

        public init(meetingA: String, meetingB: String, description: String) {
            self.meetingA = meetingA
            self.meetingB = meetingB
            self.description = description
        }
    }

    public init(meetings: [Meeting] = [], conflicts: [Conflict] = []) {
        self.meetings = meetings
        self.conflicts = conflicts
    }

    public mutating func detect() {
        conflicts.removeAll()
        for i in 0..<meetings.count {
            for j in (i+1)..<meetings.count {
                let a = meetings[i]
                let b = meetings[j]
                if a.startTime < b.endTime && b.startTime < a.endTime {
                    let desc = "\(a.title) 与 \(b.title) 时间重叠"
                    conflicts.append(Conflict(meetingA: a.title, meetingB: b.title, description: desc))
                }
                let commonAttendees = Set(a.attendees).intersection(b.attendees)
                if !commonAttendees.isEmpty && a.startTime < b.endTime && b.startTime < a.endTime {
                    let desc = "\(commonAttendees.joined(separator: ", ")) 同时在 \(a.title) 和 \(b.title) 中"
                    conflicts.append(Conflict(meetingA: a.title, meetingB: b.title, description: desc))
                }
            }
        }
    }

    public var hasConflicts: Bool { !conflicts.isEmpty }
}

// 460. 收件人确认
public struct RecipientConfirmer: Sendable, Codable, Equatable {
    public var recipients: [String]
    public var confirmed: [String]
    public var suspiciousRecipients: [String]

    public init(recipients: [String] = [], confirmed: [String] = [], suspiciousRecipients: [String] = []) {
        self.recipients = recipients
        self.confirmed = confirmed
        self.suspiciousRecipients = suspiciousRecipients
    }

    public var allConfirmed: Bool { confirmed.count == recipients.count }
    public var warningMessage: String? {
        if !suspiciousRecipients.isEmpty {
            return "可疑收件人: \(suspiciousRecipients.joined(separator: ", "))"
        }
        if !allConfirmed {
            return "还有 \(recipients.count - confirmed.count) 个收件人未确认"
        }
        return nil
    }

    public mutating func checkSuspicious(_ email: String) {
        let suspiciousPatterns = ["test", "example", "invalid", "noreply", "donotreply"]
        if suspiciousPatterns.contains(where: { email.lowercased().contains($0) }) {
            suspiciousRecipients.append(email)
        }
    }
}

// 461. 风险历史
public struct RiskHistoryTracker: Sendable, Codable, Equatable {
    public var previousRisks: [RiskRecord]
    public var currentRisk: RiskRecord?

    public struct RiskRecord: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var title: String
        public var severity: Severity
        public var status: Status
        public var createdAt: Date

        public enum Severity: String, Sendable, Codable { case low, medium, high, critical }
        public enum Status: String, Sendable, Codable { case open, mitigated, closed }

        public init(id: UUID = UUID(), title: String, severity: Severity, status: Status = .open, createdAt: Date = Date()) {
            self.id = id
            self.title = title
            self.severity = severity
            self.status = status
            self.createdAt = createdAt
        }
    }

    public init(previousRisks: [RiskRecord] = [], currentRisk: RiskRecord? = nil) {
        self.previousRisks = previousRisks
        self.currentRisk = currentRisk
    }

    public var hasUnresolvedRisks: Bool {
        if let currentRisk, currentRisk.status != .closed { return true }
        return previousRisks.contains { $0.status != .closed }
    }

    public var historicalContext: String {
        let open = previousRisks.filter { $0.status != .closed }
        guard !open.isEmpty else { return "无未解决的历史风险" }
        return "有 \(open.count) 个历史风险未关闭"
    }
}

// 462. 决策记录
public struct DecisionRecorder: Sendable, Codable, Equatable {
    public var decisions: [DecisionRecord]

    public struct DecisionRecord: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var title: String
        public var context: String
        public var options: [String]
        public var selectedOption: String
        public var rationale: String
        public var decidedBy: String
        public var createdAt: Date

        public init(id: UUID = UUID(), title: String, context: String, options: [String], selectedOption: String, rationale: String, decidedBy: String, createdAt: Date = Date()) {
            self.id = id
            self.title = title
            self.context = context
            self.options = options
            self.selectedOption = selectedOption
            self.rationale = rationale
            self.decidedBy = decidedBy
            self.createdAt = createdAt
        }
    }

    public init(decisions: [DecisionRecord] = []) {
        self.decisions = decisions
    }

    public func findRelated(to query: String) -> [DecisionRecord] {
        decisions.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.context.localizedCaseInsensitiveContains(query) }
    }
}

// 463. 审批权限
public struct ApprovalPermissionModel: Sendable, Codable, Equatable {
    public var roleHierarchy: [String: Int]
    public var currentApprover: String
    public var requiredLevel: Int

    public init(roleHierarchy: [String: Int] = ["员工": 1, "主管": 2, "经理": 3, "总监": 4, "VP": 5, "CEO": 6],
                currentApprover: String = "", requiredLevel: Int = 1) {
        self.roleHierarchy = roleHierarchy
        self.currentApprover = currentApprover
        self.requiredLevel = requiredLevel
    }

    public var currentLevel: Int { roleHierarchy[currentApprover] ?? 0 }
    public var canApprove: Bool { currentLevel >= requiredLevel }

    public func needsHigherApproval(for amount: Double) -> (needs: Bool, requiredRole: String) {
        let level: Int
        switch amount {
        case ..<1000: level = 2
        case ..<10000: level = 3
        case ..<100000: level = 4
        case ..<1000000: level = 5
        default: level = 6
        }
        let requiredRole = roleHierarchy.first(where: { $0.value == level })?.key ?? "CEO"
        return (currentLevel < level, requiredRole)
    }
}

// 464. 预算数据保护
public struct BudgetDataProtector: Sendable, Codable, Equatable {
    public var isBudgedData: Bool
    public var allowedViewers: [String]
    public var protectionLevel: ProtectionLevel

    public enum ProtectionLevel: String, Sendable, Codable {
        case `public`, internal_, restricted, confidential
    }

    public init(isBudgedData: Bool = false, allowedViewers: [String] = [], protectionLevel: ProtectionLevel = .internal_) {
        self.isBudgedData = isBudgedData
        self.allowedViewers = allowedViewers
        self.protectionLevel = protectionLevel
    }

    public mutating func classify(_ text: String) {
        let budgetKeywords = ["预算", "budget", "经费", "拨款", "财务数据", "财务报表", "利润", "revenue", "cost"]
        isBudgedData = budgetKeywords.contains { text.localizedCaseInsensitiveContains($0) }
        if isBudgedData {
            protectionLevel = .confidential
        }
    }

    public func canView(_ viewer: String) -> Bool {
        guard isBudgedData else { return true }
        return allowedViewers.contains { viewer.localizedCaseInsensitiveContains($0) }
    }
}

// 465. 措辞合规
public struct WordingComplianceChecker: Sendable, Codable, Equatable {
    public var detectedIssues: [WordingIssue]
    public var isCompliant: Bool { detectedIssues.isEmpty }

    public struct WordingIssue: Sendable, Codable, Equatable {
        public var text: String
        public var category: Category
        public var suggestion: String

        public enum Category: String, Sendable, Codable { case discriminatory, defamatory, inflammatory, unprofessional, misleading }
    }

    public init(detectedIssues: [WordingIssue] = []) {
        self.detectedIssues = detectedIssues
    }

    public mutating func analyze(_ text: String) {
        let patterns: [(String, WordingIssue.Category, String)] = [
            ("无能", .discriminatory, "用具体行为描述替代定性评价"),
            ("愚蠢", .discriminatory, "避免人身攻击"),
            ("不负责任", .defamatory, "用事实描述替代主观判断"),
            ("故意", .defamatory, "避免猜测动机"),
            ("所有人都", .inflammatory, "避免过度概括"),
            ("从来没有", .misleading, "避免绝对化表述"),
            ("最差", .unprofessional, "用客观数据替代主观评价"),
            ("零容忍", .inflammatory, "用温和措辞"),
            ("开除", .unprofessional, "使用正式HR术语"),
            ("大家都很不满意", .misleading, "避免代表他人发言"),
        ]
        for (phrase, category, suggestion) in patterns {
            if text.localizedCaseInsensitiveContains(phrase) {
                detectedIssues.append(WordingIssue(text: phrase, category: category, suggestion: suggestion))
            }
        }
    }
}
