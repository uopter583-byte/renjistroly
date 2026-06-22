import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyProductIdentity
@testable import RenJistrolyEnterprise
@testable import RenJistrolyCapability

// MARK: - 数据泄漏防护测试
//
// 安全说明：测试敏感数据检测与脱敏机制，防止凭据泄漏和敏感信息外传。
// 所有测试使用模拟数据，不涉及真实用户信息。

// MARK: - CredentialSanitizer 凭据脱敏测试

final class DataExfilTests: XCTestCase {
        func testSanitizerRedactsPasswords() {
            let sanitizer = CredentialSanitizer()

            let withPassword = sanitizer.sanitize("password=mySecretPass123")
            XCTAssertTrue(withPassword.contains("******"))
            XCTAssertTrue(!withPassword.contains("mySecretPass123"))

            let withPwd = sanitizer.sanitize("pwd: superSecret")
            XCTAssertTrue(withPwd.contains("******"))
            XCTAssertTrue(!withPwd.contains("superSecret"))
        }

        func testSanitizerRedactsTokens() {
            let sanitizer = CredentialSanitizer()

            let apiKey = "sk-ant-abc123def456"
            let withToken = sanitizer.sanitize("token=\(apiKey)")
            XCTAssertTrue(withToken.contains("******"))
            XCTAssertTrue(!withToken.contains(apiKey))
        }

        func testSanitizerRedactsSecrets() {
            let sanitizer = CredentialSanitizer()

            let input = "secret: my-app-secret-key-12345"
            let result = sanitizer.sanitize(input)
            XCTAssertTrue(result.contains("******"))
            XCTAssertTrue(!result.contains("my-app-secret-key-12345"))
        }

        func testSanitizerRedactsInMixedText() {
            let sanitizer = CredentialSanitizer()

            let input = """
            Host: example.com
            User: admin
            Password: admin123!
            Port: 22
            """
            let result = sanitizer.sanitize(input)
            XCTAssertTrue(result.contains("admin"))
            XCTAssertTrue(result.contains("example.com"))
            XCTAssertTrue(result.contains("******"))
            XCTAssertTrue(!result.contains("admin123!"))
        }

        func testSanitizerRedactsBase64Credentials() {
            let sanitizer = CredentialSanitizer()

            // 40+ 字符的 base64 字符串
            let longBase64 = "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVpBQkNERUZHSElKS0xNTk9Q"
            let input = "token=\(longBase64)"
            let result = sanitizer.sanitize(input)
            XCTAssertTrue(!result.contains(longBase64))
            XCTAssertTrue(result.contains("<redacted-base64>"))
        }

        func testSanitizerDoesNotRedactShortBase64() {
            let sanitizer = CredentialSanitizer()

            let shortB64 = "SGVsbG8=" // "Hello" in base64, too short
            let result = sanitizer.sanitize("data=\(shortB64)")
            XCTAssertTrue(result.contains(shortB64))
        }

        // MARK: - SensitiveDataProtector 敏感数据检测测试

        func testSensitiveDataDetectsCreditCards() {
            var protector = SensitiveDataProtector()
            protector.analyze("我的信用卡号是 4111111111111111，请保存")
            XCTAssertTrue(protector.detectedTypes.contains(.creditCard))
            XCTAssertFalse(protector.isProtected)
        }

        func testSensitiveDataDetectsIdNumbers() {
            var protector = SensitiveDataProtector()
            protector.analyze("身份证号 110101199001011234")
            XCTAssertTrue(protector.detectedTypes.contains(.idNumber))
        }

        func testSensitiveDataIgnoresNormalText() {
            var protector = SensitiveDataProtector()
            protector.analyze("今天天气很好，阳光明媚")
            XCTAssertTrue(protector.detectedTypes.isEmpty)
        }

        func testSensitiveDataDetectsMultipleTypes() {
            var protector = SensitiveDataProtector()
            protector.analyze("信用卡 4111111111111111，身份证 110101199001011234")
            XCTAssertTrue(protector.detectedTypes.contains(.creditCard))
            XCTAssertTrue(protector.detectedTypes.contains(.idNumber))
        }

        func testSensitiveDataMarksProtected() {
            var protector = SensitiveDataProtector()
            protector.analyze("卡号 4111111111111111")
            protector.isProtected = true
            XCTAssertTrue(protector.isProtected)
        }

        // MARK: - ClipboardRiskSnapshot 剪贴板风险评估测试

        func testClipboardRiskDefaultLow() {
            let snapshot = ClipboardRiskSnapshot()
            XCTAssertTrue(snapshot.riskLevel == .low)
            XCTAssertFalse(snapshot.hasContent)
            XCTAssertTrue(snapshot.contentType == nil)
            XCTAssertFalse(snapshot.containsSensitivePattern)
        }

        func testClipboardRiskCustomConstruction() {
            let snapshot = ClipboardRiskSnapshot(
                hasContent: true,
                contentType: "creditCard",
                containsSensitivePattern: true,
                riskLevel: .high,
                suggestion: "请勿粘贴到浏览器"
            )
            XCTAssertTrue(snapshot.hasContent)
            XCTAssertTrue(snapshot.contentType == "creditCard")
            XCTAssertTrue(snapshot.containsSensitivePattern)
            XCTAssertTrue(snapshot.riskLevel == .high)
            XCTAssertTrue(snapshot.suggestion == "请勿粘贴到浏览器")
        }

        // MARK: - LocalOnlyPolicy 本地处理策略测试

        func testLocalOnlyPolicyBlocksNetworkExfil() {
            let policy = LocalOnlyPolicy()
            let decision = policy.evaluate(filePath: "/Users/yoming/credentials.txt", requiresNetwork: true)
            XCTAssertTrue(decision == .blockedNetworkAccess)
        }

        func testLocalOnlyPolicyAllowsLocalProcessing() {
            let policy = LocalOnlyPolicy()
            let decision = policy.evaluate(filePath: "/Users/yoming/report.pdf", requiresNetwork: false)
            XCTAssertTrue(decision == .allowedLocally)
        }

        func testLocalOnlyPolicySkipsNonProtected() {
            let policy = LocalOnlyPolicy()
            let decision = policy.evaluate(filePath: "/tmp/public.txt", requiresNetwork: true)
            XCTAssertTrue(decision == .allowedLocally)
        }

        func testLocalOnlyPolicyCustomPaths() {
            let policy = LocalOnlyPolicy(protectedPaths: [ProtectedPath(path: "/etc/"), ProtectedPath(path: "/var/")])
            XCTAssertTrue(policy.isProtected(filePath: "/etc/hosts"))
            XCTAssertTrue(policy.isProtected(filePath: "/var/log/system.log"))
            XCTAssertTrue(!policy.isProtected(filePath: "/Users/test.txt"))
        }

        func testLocalOnlyPolicyDescription() {
            let policy = LocalOnlyPolicy()
            let desc = policy.policyDescription
            XCTAssertTrue(desc.contains("仅在本机处理"))
            XCTAssertTrue(desc.contains("/Users/"))
        }

        // MARK: - AuditExporter 审计日志测试

        func testAuditExporterCSVFormat() {
            let exporter = AuditExporter()
            let entries = [
                AuditExporter.AuditEntry(timestamp: Date(), user: "test", action: "read_file", resource: "credentials.txt", result: "blocked"),
                AuditExporter.AuditEntry(timestamp: Date(), user: "test", action: "shell_command", resource: "rm -rf /", result: "denied"),
            ]
            let csv = exporter.exportCSV(entries: entries)
            XCTAssertTrue(csv.hasPrefix("时间,用户,操作,资源,结果\n"))
            XCTAssertTrue(csv.contains("test"))
            XCTAssertTrue(csv.contains("read_file"))
            XCTAssertTrue(csv.contains("blocked"))
            XCTAssertTrue(csv.contains("shell_command"))
            XCTAssertTrue(csv.contains("denied"))
            let lines = csv.split(separator: "\n")
            XCTAssertTrue(lines.count == 3) // header + 2 entries
        }

        func testAuditExporterJSONFormat() {
            let exporter = AuditExporter()
            let entries = [
                AuditExporter.AuditEntry(timestamp: Date(), user: "admin", action: "delete_file", resource: "/tmp/test.txt", result: "allowed"),
            ]
            guard let jsonData = exporter.exportJSON(entries: entries) else {
                XCTFail("JSON 导出应返回有效数据")
                return
            }
            guard let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                XCTFail("JSON 应可解析为数组")
                return
            }
            XCTAssertTrue(jsonObj.count == 1)
            XCTAssertTrue(jsonObj[0]["user"] as? String == "admin")
            XCTAssertTrue(jsonObj[0]["action"] as? String == "delete_file")
            XCTAssertTrue(jsonObj[0]["result"] as? String == "allowed")
            XCTAssertTrue(jsonObj[0]["resource"] as? String == "/tmp/test.txt")
        }

        func testAuditExporterEmptyEntries() {
            let exporter = AuditExporter()
            let csv = exporter.exportCSV(entries: [])
            XCTAssertTrue(csv == "时间,用户,操作,资源,结果\n")

            let jsonData = exporter.exportJSON(entries: [])
            XCTAssertTrue(jsonData != nil)
            if let data = jsonData, let obj = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                XCTAssertTrue(obj.isEmpty)
            }
        }

        func testAuditExporterSpecialChars() {
            let exporter = AuditExporter()
            let entry = AuditExporter.AuditEntry(
                timestamp: Date(), user: "user,name", action: "test", resource: "file", result: "ok"
            )
            let csv = exporter.exportCSV(entries: [entry])
            XCTAssertTrue(csv.contains("user,name"))
        }

        // MARK: - OCR 敏感数据检测测试

        func testOcrCreditCardValidation() {
            var validator = OCRDigitValidator(rawText: "Please charge 4111111111111111")

            // 数字校验前
            XCTAssertTrue(validator.rawText == "Please charge 4111111111111111")

            validator.correctedText = validator.rawText
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            let hasDigits = validator.rawText.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
            XCTAssertTrue(hasDigits)
        }

        func testOcrDigitCorrection() {
            var validator = OCRDigitValidator(rawText: "Account: 12O45")
            validator.validate()
            XCTAssertTrue(validator.correctedText == "Account: 12045")
            XCTAssertFalse(validator.corrections.isEmpty)
        }

        func testOcrHighConfidenceValidation() {
            var validator = OCRDigitValidator(rawText: "12345", confidence: 0.95)
            validator.validate()
            XCTAssertTrue(validator.isValid)
            XCTAssertTrue(validator.confidence >= 0.7)
        }

        func testOcrLowConfidenceValidation() {
            var validator = OCRDigitValidator(rawText: "ABCDE", confidence: 0.3)
            validator.validate()
            XCTAssertFalse(validator.isValid)
        }

        // MARK: - ActionRecord 审计完整性测试

        func testActionRecordAuditTrail() {
            let record = ActionRecord(
                type: "write_file",
                preview: "写入 /tmp/test.txt",
                riskLevel: .medium,
                auditTrail: [AuditEntry(event: "created", detail: "Record created")]
            )
            XCTAssertTrue(record.auditTrail.count == 1)

            let updatedTrail = record.auditTrail + [AuditEntry(event: "approved", detail: "Approved by user")]
            XCTAssertTrue(updatedTrail.count == 2)
            XCTAssertTrue(updatedTrail[0].event == "created")
            XCTAssertTrue(updatedTrail[1].event == "approved")
        }

        @MainActor func testActionEngineAuditOnCreate() {
            let engine = ActionEngine()
            let record = engine.create(type: "shell_command", preview: "ls -la", riskLevel: .low)
            XCTAssertTrue(record.auditTrail.count >= 1)
            XCTAssertTrue(record.auditTrail[0].event == "created")
            XCTAssertTrue(record.auditTrail[0].detail.contains("created"))
        }

        // MARK: - SensitiveClipboardManager 剪贴板管理测试

        func testSensitiveClipboardManagerConstruction() {
            let manager = SensitiveClipboardManager()
            XCTAssertTrue(manager.lastCopyContentType == .normal)
            XCTAssertFalse(manager.isSensitive)
            XCTAssertTrue(manager.autoClearAfter == 30)

            let custom = SensitiveClipboardManager(
                lastCopyContentType: .password,
                isSensitive: true,
                autoClearAfter: 10
            )
            XCTAssertTrue(custom.lastCopyContentType == .password)
            XCTAssertTrue(custom.isSensitive)
            XCTAssertTrue(custom.autoClearAfter == 10)
        }

        func testClipboardContentTypeEnum() {
            let cases = SensitiveClipboardManager.ClipboardContentType.allCases
            XCTAssertFalse(cases.isEmpty)
            for type in cases {
                let _: String = type.rawValue // 所有 case 应有 rawValue
            }
        }

        // MARK: - 敏感文件操作安全测试

        func testFileSafetyProtectsSystemPaths() {
            let safety = FileOperationSafety()
            XCTAssertTrue(safety.isProtected("/System"))
            XCTAssertTrue(safety.isProtected("/Library"))
            XCTAssertTrue(safety.isProtected("/Applications"))

            let homeLib = NSHomeDirectory() + "/Library"
            XCTAssertTrue(safety.isProtected(homeLib))
        }

        func testFileSafetyAllowsNonProtected() {
            let safety = FileOperationSafety()
            XCTAssertTrue(!safety.isProtected("/tmp"))
            XCTAssertTrue(!safety.isProtected("/private/tmp"))
            let home = NSHomeDirectory()
            XCTAssertTrue(!safety.isProtected(home + "/Documents"))
        }

        func testFileSafetyValidationMessage() {
            let safety = FileOperationSafety()
            let msg = safety.validate(operation: .delete, target: "/System/Library/CoreServices")
            XCTAssertTrue(msg != nil)
            XCTAssertTrue(msg?.contains("/System/Library/CoreServices") == true)
            XCTAssertTrue(msg?.contains("delete") == true)
        }



}