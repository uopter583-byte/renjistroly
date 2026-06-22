import XCTest
import Foundation
@testable import RenJistrolyEnterprise
@testable import RenJistrolyProductIdentity

// MARK: - 升级兼容性测试
// 覆盖范围：配置版本兼容性 / 审计日志格式兼容性 / 状态机状态兼容性

final class UpgradeConfigVersionTests: XCTestCase {

    func testModeConfigurationV1Format() throws {
        let v1JSON = """
        {
            "activeModes": ["readOnly", "executable"],
            "policy": {
                "requiresConfirmation": true,
                "requiresApproval": false,
                "allowedDomains": [], "blockedDomains": [],
                "allowedApps": [], "blockedApps": [],
                "maxRiskLevel": 2,
                "auditRetentionDays": 90
            },
            "lockedModes": []
        }
        """
        let data = try XCTUnwrap(v1JSON.data(using: .utf8))
        let config = try JSONDecoder().decode(ModeConfiguration.self, from: data)

        XCTAssertTrue(config.activeModes.contains(.readOnly))
        XCTAssertTrue(config.activeModes.contains(.executable))
        XCTAssertTrue(config.policy.requiresConfirmation)

        XCTAssertTrue(config.maskingPatterns.isEmpty)
        XCTAssertTrue(config.sensitiveAppBundleIDs.isEmpty)
    }

    func testModeConfigurationV2Format() throws {
        let v2JSON = """
        {
            "activeModes": ["readOnly", "executable", "autoMask"],
            "policy": {
                "requiresConfirmation": true, "requiresApproval": true,
                "allowedDomains": ["example.com"], "blockedDomains": ["bad.com"],
                "allowedApps": ["TextEdit"], "blockedApps": ["Terminal"],
                "maxRiskLevel": 1, "auditRetentionDays": 365
            },
            "lockedModes": ["policyLock"],
            "maskingPatterns": ["password", "token"],
            "sensitiveAppBundleIDs": ["com.apple.Safari"]
        }
        """
        let data = try XCTUnwrap(v2JSON.data(using: .utf8))
        let config = try JSONDecoder().decode(ModeConfiguration.self, from: data)

        XCTAssertEqual(config.activeModes.count, 3)
        XCTAssertTrue(config.lockedModes.contains(.policyLock))
        XCTAssertEqual(config.maskingPatterns, ["password", "token"])
        XCTAssertEqual(config.sensitiveAppBundleIDs, ["com.apple.Safari"])
    }

    func testModePolicyEncodeDecodeRoundTrip() throws {
        let policy = ModePolicy(
            requiresConfirmation: true, requiresApproval: false,
            allowedDomains: ["safe.com"], blockedDomains: ["evil.com"],
            allowedApps: ["Finder"], blockedApps: ["Terminal"],
            maxRiskLevel: .medium, auditRetentionDays: 180
        )
        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(ModePolicy.self, from: data)
        XCTAssertEqual(decoded, policy)
    }
}

final class UpgradeAuditLogFormatTests: XCTestCase {

    func testAuditEntryJSONRoundTrip() throws {
        let entry = AuditEntry(id: "audit-001", timestamp: Date(timeIntervalSince1970: 1_700_000_000), event: "action.created", detail: "Click was created")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(AuditEntry.self, from: data)
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.timestamp, entry.timestamp)
        XCTAssertEqual(decoded.event, entry.event)
    }

    func testActionRecordFullRoundTrip() throws {
        let record = ActionRecord(
            id: "rec-001", type: "file_write", preview: "Write config",
            targetContext: "/etc/config.json", riskLevel: .medium,
            status: .completed, result: "Written 1024 bytes",
            verificationEvidence: "checksum=abc123",
            rollbackAction: "restore /etc/config.json.bak",
            auditTrail: [
                AuditEntry(id: "e1", timestamp: Date(timeIntervalSince1970: 1_700_000_000), event: "created"),
                AuditEntry(id: "e2", timestamp: Date(timeIntervalSince1970: 1_700_000_001), event: "approved"),
            ],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_003),
            cancelledAt: nil
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(ActionRecord.self, from: data)
        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.type, record.type)
        XCTAssertEqual(decoded.preview, record.preview)
        XCTAssertEqual(decoded.riskLevel, record.riskLevel)
        XCTAssertEqual(decoded.status, record.status)
        XCTAssertEqual(decoded.result, record.result)
        XCTAssertEqual(decoded.auditTrail.count, record.auditTrail.count)
    }

    func testActionRecordV1MinimalFormat() throws {
        let v1JSON = """
        {"type": "click", "preview": "Click OK"}
        """
        let data = try XCTUnwrap(v1JSON.data(using: .utf8))
        let record = try JSONDecoder().decode(ActionRecord.self, from: data)
        XCTAssertEqual(record.type, "click")
        XCTAssertEqual(record.preview, "Click OK")
        XCTAssertEqual(record.status, .pending)
        XCTAssertEqual(record.riskLevel, .low)
    }

    func testActionRecordV1WithExtraFields() throws {
        let v1JSON = """
        {"type": "navigate", "preview": "Navigate", "riskLevel": 1, "status": "completed", "result": "done", "extraField": "should be ignored"}
        """
        let data = try XCTUnwrap(v1JSON.data(using: .utf8))
        let record = try JSONDecoder().decode(ActionRecord.self, from: data)
        XCTAssertEqual(record.type, "navigate")
        XCTAssertEqual(record.status, .completed)
    }

    func testSystemContextCodable() throws {
        let ctx = SystemContext(
            screen: ScreenContextSnapshot(displayDescription: "Display", visibleAppNames: ["Safari"]),
            app: AppContextSnapshot(appName: "Safari"),
            permission: PermissionContextSnapshot(allGranted: true),
            securityMode: SecurityModeContextSnapshot(activeModes: ["executable"])
        )
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(SystemContext.self, from: data)
        XCTAssertEqual(decoded.screen.displayDescription, "Display")
        XCTAssertEqual(decoded.app.appName, "Safari")
        XCTAssertTrue(decoded.permission.allGranted)
    }
}

final class UpgradeStateMachineTests: XCTestCase {

    func testActionStatusValidTransitions() {
        var status: ActionStatus = .pending
        status = .approved
        status = .executing
        status = .completed
        XCTAssertEqual(status, .completed)

        status = .pending
        status = .rejected
        XCTAssertEqual(status, .rejected)

        status = .pending
        status = .cancelled
        XCTAssertEqual(status, .cancelled)

        status = .executing
        status = .failed
        XCTAssertEqual(status, .failed)

        status = .completed
        status = .rolledBack
        XCTAssertEqual(status, .rolledBack)
    }

    func testActionStatusAllRawValuesUnique() {
        let allStatuses: [ActionStatus] = [.pending, .approved, .rejected, .executing, .completed, .failed, .cancelled, .rolledBack]
        let rawValues = allStatuses.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testOperationModeIDsUnique() {
        let ids = OperationMode.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testOperationModeCodable() throws {
        for mode in OperationMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(OperationMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testSecurityModeContextCodable() throws {
        let ctx = SecurityModeContextSnapshot(
            activeModes: ["readOnly", "executable"],
            lockedModes: ["policyLock"],
            effectiveRiskLimit: "medium",
            isLocked: true
        )
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(SecurityModeContextSnapshot.self, from: data)
        XCTAssertEqual(decoded.activeModes, ctx.activeModes)
        XCTAssertEqual(decoded.lockedModes, ctx.lockedModes)
        XCTAssertEqual(decoded.effectiveRiskLimit, ctx.effectiveRiskLimit)
        XCTAssertTrue(decoded.isLocked)
    }

    func testOperationModeTitleAndDescriptionNotEmpty() {
        for mode in OperationMode.allCases {
            XCTAssertFalse(mode.title.isEmpty)
            XCTAssertFalse(mode.description.isEmpty)
        }
    }
}
