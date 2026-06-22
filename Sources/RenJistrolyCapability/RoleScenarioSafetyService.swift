import Foundation
import RenJistrolyModels

// MARK: - Role Scenario Safety Service

public struct RoleSafetyResult: Sendable, Codable, Equatable {
    public var passed: Bool
    public var guardName: String
    public var message: String
    public var details: String?
}

public actor RoleScenarioSafetyService {

    public init() {}

    // MARK: - Finance Guards (436-445)

    public func validateOCRDigits(_ rawText: String) -> RoleSafetyResult {
        var validator = OCRDigitValidator(rawText: rawText)
        validator.validate()
        return RoleSafetyResult(
            passed: validator.isValid,
            guardName: "OCR数字校验纠错",
            message: validator.isValid ? "OCR数字校验通过" : "OCR数字置信度不足 (\(validator.confidence))",
            details: validator.corrections.map { "\($0.from)→\($0.to)(×\($0.count))" }.joined(separator: ", ")
        )
    }

    public func validateAmount(_ amount: Double, min: Double, max: Double, currency: String = "CNY") -> RoleSafetyResult {
        let v = AmountValidator(detectedAmount: amount, expectedRange: min...max, currency: currency)
        return RoleSafetyResult(
            passed: v.isInRange,
            guardName: "金额验证",
            message: v.formatted(),
            details: "偏差: \(v.deviation)"
        )
    }

    public func protectSensitiveData(_ text: String) -> SensitiveDataProtector {
        var protector = SensitiveDataProtector()
        protector.analyze(text)
        return protector
    }

    public func evaluatePaymentApproval(amount: Double) -> PaymentApprovalFlow {
        PaymentApprovalFlow(amount: amount)
    }

    public func detectExcelFormulas(_ text: String) -> ExcelFormulaAwareness {
        var awareness = ExcelFormulaAwareness()
        awareness.analyze(text)
        return awareness
    }

    public func classifyTaxData(_ text: String, allowedRecipients: [String]) -> TaxInfoIsolator {
        var isolator = TaxInfoIsolator(allowedRecipients: allowedRecipients)
        isolator.classify(text)
        return isolator
    }

    public func classifySensitiveClipboard(_ text: String) -> SensitiveClipboardManager {
        var manager = SensitiveClipboardManager()
        manager.classify(text)
        return manager
    }

    public func validateReconciliation(expected: Double, actual: Double, threshold: Double = 0.01) -> ReconciliationErrorThreshold {
        ReconciliationErrorThreshold(expectedAmount: expected, actualAmount: actual, threshold: threshold)
    }

    // MARK: - HR Guards (446-455)

    public func maskResumeData(_ text: String, fields: Set<ResumeDataMasker.ResumeField>? = nil) -> String {
        ResumeDataMasker.mask(text, fields: fields ?? Set(ResumeDataMasker.ResumeField.allCases))
    }

    public func checkComplianceTone(_ text: String) -> ComplianceToneChecker {
        var checker = ComplianceToneChecker()
        checker.analyze(text)
        return checker
    }

    public func checkPrivacyBoundary(_ text: String, purpose: String) -> PrivacyBoundaryGuard {
        var guard_ = PrivacyBoundaryGuard()
        _ = guard_.analyze(text, purpose: purpose)
        return guard_
    }

    public func validateField(field: String, value: String, rules: [String: FieldValidator.FieldRule]) -> FieldValidator {
        var v = FieldValidator(fieldRules: rules)
        _ = v.validate(field: field, value: value)
        return v
    }

    // MARK: - Manager Guards (456-465)

    public func detectMeetingConflicts(_ meetings: [MeetingConflictDetector.Meeting]) -> MeetingConflictDetector {
        var detector = MeetingConflictDetector(meetings: meetings)
        detector.detect()
        return detector
    }

    public func analyzeChartTrend(points: [ChartTrendInterpreter.ChartDataPoint]) -> ChartTrendInterpreter {
        var interpreter = ChartTrendInterpreter(dataPoints: points)
        interpreter.analyze()
        return interpreter
    }

    public func checkWordingCompliance(_ text: String) -> RoleSafetyResult {
        var checker = WordingComplianceChecker()
        checker.analyze(text)
        let issues = checker.detectedIssues
        return RoleSafetyResult(
            passed: checker.isCompliant,
            guardName: "措辞合规检查",
            message: checker.isCompliant ? "措辞合规" : "发现 \(issues.count) 个合规问题",
            details: issues.map { "[\($0.category.rawValue)] \($0.text): \($0.suggestion)" }.joined(separator: "; ")
        )
    }

    // MARK: - Multi-guard check (runs all applicable guards for a role)

    public enum Role: String, Sendable {
        case finance, hr, manager
    }

    public func runAllGuards(for role: Role, context: [String: String]) -> [RoleSafetyResult] {
        switch role {
        case .finance:
            var results: [RoleSafetyResult] = []
            if let text = context["ocr_text"] {
                results.append(validateOCRDigits(text))
            }
            if let amountStr = context["amount"], let amount = Double(amountStr),
               let minStr = context["amount_min"], let min = Double(minStr),
               let maxStr = context["amount_max"], let max = Double(maxStr) {
                results.append(validateAmount(amount, min: min, max: max))
            }
            return results

        case .hr:
            var results: [RoleSafetyResult] = []
            if let text = context["compliance_text"] {
                let toneCheck = checkComplianceTone(text)
                results.append(RoleSafetyResult(
                    passed: toneCheck.isCompliant,
                    guardName: "合规语气检查",
                    message: toneCheck.isCompliant ? "语气合规" : "发现 \(toneCheck.detectedIssues.count) 个语气问题",
                    details: toneCheck.detectedIssues.map { "\($0.phrase): \($0.suggestion)" }.joined(separator: "; ")
                ))
            }
            if let fieldValue = context["field_value"], let fieldName = context["field_name"] {
                let rules: [String: FieldValidator.FieldRule] = [
                    fieldName: .init(required: true, minLength: 1, maxLength: 100)
                ]
                let fv = validateField(field: fieldName, value: fieldValue, rules: rules)
                results.append(RoleSafetyResult(
                    passed: fv.isValid,
                    guardName: "字段验证",
                    message: fv.isValid ? "字段验证通过" : "字段验证失败",
                    details: fv.validationErrors.values.joined(separator: "; ")
                ))
            }
            return results

        case .manager:
            var results: [RoleSafetyResult] = []
            if let text = context["wording_text"] {
                results.append(checkWordingCompliance(text))
            }
            return results
        }
    }
}
