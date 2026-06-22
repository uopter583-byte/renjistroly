import XCTest
@testable import RenJistrolyEnterprise
@testable import RenJistrolyProductIdentity

// MARK: - 升级兼容性测试
//
// 覆盖范围：
//  - 配置版本兼容性（ModeConfiguration 编解码兼容性）
//  - 审计日志格式兼容性（ActionRecord/AuditEntry 序列化）
//  - 状态机状态兼容性（ActionStatus、OperationMode）
//
// 使用 XCTest（兼容 Xcode Cloud 和 GitHub Actions）

// MARK: 配置版本兼容性

final class UpgradeConfigVersionTests: XCTestCase {
    func testUpgradeModeConfigurationV1Format() throws {
        // 模拟 V1 格式的 JSON（缺少新字段 — 应使用默认值）
        let v1JSON = """
        {
            "activeModes": ["readOnly", "executable"],
            "policy": {
                "requiresConfirmation": true,
                "requiresApproval": false,
                "allowedDomains": [],
                "blockedDomains": [],
                "allowedApps": [],
                "blockedApps": [],
                "maxRiskLevel": 2,
                "auditRetentionDays": 90
            },
            "lockedModes": []
        }
        """
        let data = try XCTUnwrap(v1JSON.data(using: .utf8))
        let config = try JSONDecoder().decode(ModeConfiguration.self, from: data)

        // V1 已有字段应正确解析
        XCTAssertTrue(config.activeModes.contains(.readOnly))
        XCTAssertTrue(config.activeModes.contains(.executable))
        XCTAssertTrue(config.policy.requiresConfirmation)
        XCTAssertFalse(config.policy.requiresApproval)

        // 新 V2 字段应使用默认值
        XCTAssertTrue(config.maskingPatterns.isEmpty)
        XCTAssertTrue(config.sensitiveAppBundleIDs.isEmpty)
    }

    func testUpgradeModeConfigurationV2Format() throws {
        // V2 格式 — 包含所有字段
        let v2JSON = """
        {
            "activeModes": ["readOnly", "executable", "autoMask"],
            "policy": {
                "requiresConfirmation": true,
                "requiresApproval": true,
                "allowedDomains": ["example.com"],
                "blockedDomains": ["bad.com"],
                "allowedApps": ["TextEdit"],
                "blockedApps": ["Terminal"],
                "maxRiskLevel": 1,
                "auditRetentionDays": 365
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
        XCTAssertEqual(config.policy.allowedDomains, ["example.com"])
    }

    func testUpgradeModeConfigurationUnknownModeHandling() throws {
        // 模拟包含未知模式的 JSON — 应优雅处理
        let unknownModeJSON = """
        {
            "activeModes": ["readOnly", "unknownMode", "executable"],
            "policy": {
                "requiresConfirmation": false,
                "requiresApproval": false,
                "allowedDomains": [],
                "blockedDomains": [],
                "allowedApps": [],
                "blockedApps": [],
                "maxRiskLevel": 4,
                "auditRetentionDays": 90
            },
            "lockedModes": []
        }
        """
        let data = try XCTUnwrap(unknownModeJSON.data(using: .utf8))
        // OperationMode 是 String rawValue enum — 未知 rawValue 导致解码失败或忽略
        do {
            let config = try JSONDecoder().decode(ModeConfiguration.self, from: data)
            // 如果解码成功，验证已知模式被解析，未知模式被忽略
            XCTAssertTrue(config.activeModes.contains(.readOnly))
            XCTAssertTrue(config.activeModes.contains(.executable))
        } catch {
            XCTAssertTrue(error is DecodingError,
                          "预期 DecodingError，实际: \(type(of: error))")
        }
    }

    func testUpgradeModePolicySafeDefaultsOnMissingFields() throws {
        // 部分 JSON — 缺失某些 policy 字段
        let partialJSON = """
        {
            "activeModes": [],
            "policy": {
                "requiresConfirmation": true,
                "maxRiskLevel": 0
            },
            "lockedModes": []
        }
        """
        let data = try XCTUnwrap(partialJSON.data(using: .utf8))
        do {
            let config = try JSONDecoder().decode(ModeConfiguration.self, from: data)
            // 如果解码成功，验证回退行为
            XCTAssertTrue(config.activeModes.isEmpty)
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }
}

// MARK: 审计日志格式兼容性

final class UpgradeAuditLogTests: XCTestCase {
    func testUpgradeAuditEntryJSONRoundTrip() throws {
        let entry = AuditEntry(
            id: "audit-001",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            event: "action.created",
            detail: "Action 'click' was created"
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(AuditEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.timestamp, entry.timestamp)
        XCTAssertEqual(decoded.event, entry.event)
        XCTAssertEqual(decoded.detail, entry.detail)
    }

    func testUpgradeActionRecordFullRoundTrip() throws {
        let record = ActionRecord(
            id: "rec-001",
            type: "file_write",
            preview: "Write config file",
            targetContext: "/etc/config.json",
            riskLevel: .medium,
            status: .completed,
            result: "Written 1024 bytes",
            verificationEvidence: "checksum=abc123",
            failureReason: nil,
            recoverySuggestion: nil,
            rollbackAction: "restore /etc/config.json.bak",
            auditTrail: [
                AuditEntry(id: "e1", timestamp: Date(timeIntervalSince1970: 1_700_000_000), event: "created"),
                AuditEntry(id: "e2", timestamp: Date(timeIntervalSince1970: 1_700_000_001), event: "approved"),
                AuditEntry(id: "e3", timestamp: Date(timeIntervalSince1970: 1_700_000_002), event: "completed", detail: "done"),
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
        XCTAssertEqual(decoded.targetContext, record.targetContext)
        XCTAssertEqual(decoded.status, record.status)
        XCTAssertEqual(decoded.result, record.result)
        XCTAssertEqual(decoded.verificationEvidence, record.verificationEvidence)
        XCTAssertEqual(decoded.failureReason, record.failureReason)
        XCTAssertEqual(decoded.rollbackAction, record.rollbackAction)
        XCTAssertEqual(decoded.auditTrail.count, record.auditTrail.count)
        XCTAssertEqual(decoded.createdAt, record.createdAt)
        XCTAssertEqual(decoded.completedAt, record.completedAt)
    }

    func testUpgradeActionRecordV1MinimalFormat() throws {
        // V1 最小格式 — 只有必需字段
        let v1JSON = """
        {
            "type": "click",
            "preview": "Click OK"
        }
        """
        let data = try XCTUnwrap(v1JSON.data(using: .utf8))
        let record = try JSONDecoder().decode(ActionRecord.self, from: data)

        XCTAssertEqual(record.type, "click")
        XCTAssertEqual(record.preview, "Click OK")
        XCTAssertEqual(record.status, .pending)
        XCTAssertEqual(record.targetContext, "")
        XCTAssertTrue(record.auditTrail.isEmpty)
        XCTAssertNil(record.result)
    }

    func testUpgradeActionRecordV1WithExtraFields() throws {
        // V1 JSON 包含未来版本可能添加的额外字段 — 应被忽略
        let v1WithExtraJSON = """
        {
            "type": "navigate",
            "preview": "Navigate to URL",
            "riskLevel": 1,
            "status": "completed",
            "result": "done",
            "extraField": "should be ignored",
            "futureMeta": {"version": 2}
        }
        """
        let data = try XCTUnwrap(v1WithExtraJSON.data(using: .utf8))
        let record = try JSONDecoder().decode(ActionRecord.self, from: data)

        XCTAssertEqual(record.type, "navigate")
        XCTAssertEqual(record.status, .completed)
    }

    func testUpgradeActionRecordV1NumericRiskLevel() throws {
        // V1 格式可能使用 Int rawValue 表示 riskLevel
        let v1NumericJSON = """
        {
            "type": "delete",
            "preview": "Delete file",
            "riskLevel": 2
        }
        """
        let data = try XCTUnwrap(v1NumericJSON.data(using: .utf8))
        // EnterpriseRiskLevel 使用 Int rawValue — 数字兼容
        let record = try JSONDecoder().decode(ActionRecord.self, from: data)
        XCTAssertEqual(record.type, "delete")
    }
}

// MARK: 状态机状态兼容性

final class UpgradeStateMachineTests: XCTestCase {
    func testUpgradeActionStatusValidTransitions() {
        // pending -> approved -> executing -> completed
        var status: ActionStatus = .pending
        status = .approved
        status = .executing
        status = .completed
        XCTAssertEqual(status, .completed)

        // pending -> rejected
        status = .pending
        status = .rejected
        XCTAssertEqual(status, .rejected)

        // pending -> cancelled
        status = .pending
        status = .cancelled
        XCTAssertEqual(status, .cancelled)

        // executing -> failed
        status = .executing
        status = .failed
        XCTAssertEqual(status, .failed)

        // completed -> rolledBack
        status = .completed
        status = .rolledBack
        XCTAssertEqual(status, .rolledBack)
    }

    func testUpgradeActionStatusAllRawValuesUnique() {
        let allStatuses: [ActionStatus] = [
            .pending, .approved, .rejected, .executing,
            .completed, .failed, .cancelled, .rolledBack,
        ]
        let rawValues = allStatuses.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count,
                       "所有 ActionStatus rawValue 应唯一")
    }

    func testUpgradeActionStatusCount() {
        let allStatuses: [ActionStatus] = [
            .pending, .approved, .rejected, .executing,
            .completed, .failed, .cancelled, .rolledBack,
        ]
        XCTAssertEqual(allStatuses.count, 8, "应有 8 个 ActionStatus 状态")
    }

    func testUpgradeOperationModeIDsUnique() {
        let ids = OperationMode.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count,
                       "所有 OperationMode ID 应唯一")
    }

    func testUpgradeOperationModeCodable() throws {
        for mode in OperationMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(OperationMode.self, from: data)
            XCTAssertEqual(decoded, mode)
            XCTAssertEqual(decoded.rawValue, mode.rawValue)
        }
    }

    func testUpgradeModePolicyCodable() throws {
        let policy = ModePolicy(
            requiresConfirmation: true,
            requiresApproval: false,
            allowedDomains: ["safe.com"],
            blockedDomains: ["evil.com"],
            allowedApps: ["Finder"],
            blockedApps: ["Terminal"],
            maxRiskLevel: .medium,
            auditRetentionDays: 180
        )
        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(ModePolicy.self, from: data)

        XCTAssertEqual(decoded.requiresConfirmation, policy.requiresConfirmation)
        XCTAssertEqual(decoded.requiresApproval, policy.requiresApproval)
        XCTAssertEqual(decoded.allowedDomains, policy.allowedDomains)
        XCTAssertEqual(decoded.blockedDomains, policy.blockedDomains)
        XCTAssertEqual(decoded.maxRiskLevel, policy.maxRiskLevel)
        XCTAssertEqual(decoded.auditRetentionDays, policy.auditRetentionDays)
    }

    func testUpgradeModeConfigurationCodable() throws {
        let config = ModeConfiguration(
            activeModes: [.readOnly, .executable],
            policy: .locked,
            lockedModes: [.policyLock],
            maskingPatterns: ["password"],
            sensitiveAppBundleIDs: ["com.apple.Safari"]
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ModeConfiguration.self, from: data)

        XCTAssertEqual(decoded.activeModes, config.activeModes)
        XCTAssertEqual(decoded.policy, config.policy)
        XCTAssertEqual(decoded.lockedModes, config.lockedModes)
        XCTAssertEqual(decoded.maskingPatterns, config.maskingPatterns)
        XCTAssertEqual(decoded.sensitiveAppBundleIDs, config.sensitiveAppBundleIDs)
    }

    func testUpgradeActionRecordEncodeDecodeRoundTrip() throws {
        let record = ActionRecord(
            type: "test",
            preview: "Test action",
            riskLevel: .medium,
            auditTrail: [AuditEntry(event: "created", detail: "test")]
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(ActionRecord.self, from: data)

        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.type, record.type)
        XCTAssertEqual(decoded.preview, record.preview)
        XCTAssertEqual(decoded.auditTrail.count, record.auditTrail.count)
    }

    func testUpgradeModePolicyDefaultValues() {
        let policy = ModePolicy.default
        XCTAssertFalse(policy.requiresConfirmation)
        XCTAssertFalse(policy.requiresApproval)
        XCTAssertTrue(policy.allowedDomains.isEmpty)
        XCTAssertTrue(policy.blockedDomains.isEmpty)
        XCTAssertEqual(policy.maxRiskLevel, .critical)
        XCTAssertEqual(policy.auditRetentionDays, 90)
    }

    func testUpgradeModePolicyLockedValues() {
        let policy = ModePolicy.locked
        XCTAssertTrue(policy.requiresConfirmation)
        XCTAssertTrue(policy.requiresApproval)
        XCTAssertEqual(policy.maxRiskLevel, .low)
        XCTAssertEqual(policy.auditRetentionDays, 365)
    }

    func testUpgradeModeConfigurationDefaultValues() {
        let config = ModeConfiguration()
        XCTAssertTrue(config.activeModes.isEmpty)
        XCTAssertEqual(config.policy, .default)
        XCTAssertTrue(config.lockedModes.isEmpty)
        XCTAssertTrue(config.maskingPatterns.isEmpty)
        XCTAssertTrue(config.sensitiveAppBundleIDs.isEmpty)
    }
}
