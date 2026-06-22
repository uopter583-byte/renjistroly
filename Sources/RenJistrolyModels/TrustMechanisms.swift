import Foundation
import CoreGraphics

// MARK: - 506. 点击预览+确认 (ClickPreview)
// 执行点击前预览目标并确认

public struct ClickPreview: Sendable, Codable, Equatable {
    public struct ClickTarget: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var targetDescription: String
        public var targetApp: String?
        public var elementRole: String?
        public var elementLabel: String?
        public var screenPosition: String?
        public var actionDescription: String
        public var isConfirmed: Bool

        public init(
            id: UUID = UUID(),
            targetDescription: String,
            targetApp: String? = nil,
            elementRole: String? = nil,
            elementLabel: String? = nil,
            screenPosition: String? = nil,
            actionDescription: String,
            isConfirmed: Bool = false
        ) {
            self.id = id
            self.targetDescription = targetDescription
            self.targetApp = targetApp
            self.elementRole = elementRole
            self.elementLabel = elementLabel
            self.screenPosition = screenPosition
            self.actionDescription = actionDescription
            self.isConfirmed = isConfirmed
        }

        public var previewSummary: String {
            var parts: [String] = ["🖱️ \(actionDescription)"]
            if let app = targetApp { parts.append("  应用：\(app)") }
            if let label = elementLabel { parts.append("  目标：\(label)") }
            if let pos = screenPosition { parts.append("  位置：\(pos)") }
            return parts.joined(separator: "\n")
        }
    }

    public var pendingClick: ClickTarget?
    public var previewEnabled: Bool
    public var requireConfirmation: Bool

    public init(pendingClick: ClickTarget? = nil, previewEnabled: Bool = true, requireConfirmation: Bool = true) {
        self.pendingClick = pendingClick
        self.previewEnabled = previewEnabled
        self.requireConfirmation = requireConfirmation
    }

    public mutating func setPendingClick(_ target: ClickTarget) {
        pendingClick = target
    }

    public mutating func confirm() {
        pendingClick?.isConfirmed = true
    }

    public mutating func reject() {
        pendingClick = nil
    }

    public var needsConfirmation: Bool {
        guard let click = pendingClick, previewEnabled && requireConfirmation else { return false }
        return !click.isConfirmed
    }

    public var promptMessage: String? {
        guard let click = pendingClick, needsConfirmation else { return nil }
        return click.previewSummary
    }
}

// MARK: - 507. 发送预览+确认 (SendPreview)
// 发送消息前预览内容并确认

public struct SendPreview: Sendable, Codable, Equatable {
    public struct PendingSend: Sendable, Codable, Equatable {
        public var channelDescription: String
        public var recipients: [String]
        public var subject: String?
        public var bodyPreview: String
        public var attachments: [String]
        public var scheduledTime: Date?
        public var isConfirmed: Bool

        public init(
            channelDescription: String,
            recipients: [String],
            subject: String? = nil,
            bodyPreview: String,
            attachments: [String] = [],
            scheduledTime: Date? = nil,
            isConfirmed: Bool = false
        ) {
            self.channelDescription = channelDescription
            self.recipients = recipients
            self.subject = subject
            self.bodyPreview = bodyPreview
            self.attachments = attachments
            self.scheduledTime = scheduledTime
            self.isConfirmed = isConfirmed
        }

        public var summary: String {
            var parts: [String] = ["📨 即将发送"]
            parts.append("  渠道：\(channelDescription)")
            parts.append("  收件人：\(recipients.joined(separator: "、"))")
            if let subj = subject, !subj.isEmpty {
                parts.append("  主题：\(subj)")
            }
            if !attachments.isEmpty {
                parts.append("  附件：\(attachments.joined(separator: "、"))")
            }
            parts.append("  内容预览：")
            parts.append("  ```")
            parts.append("  \(bodyPreview.prefix(200))")
            parts.append("  ```")
            return parts.joined(separator: "\n")
        }
    }

    public var pendingSend: PendingSend?
    public var requireConfirmation: Bool

    public init(pendingSend: PendingSend? = nil, requireConfirmation: Bool = true) {
        self.pendingSend = pendingSend
        self.requireConfirmation = requireConfirmation
    }

    public mutating func setPendingSend(_ send: PendingSend) {
        pendingSend = send
    }

    public mutating func confirm() {
        pendingSend?.isConfirmed = true
    }

    public mutating func reject() {
        pendingSend = nil
    }

    public var needsConfirmation: Bool {
        guard let send = pendingSend, requireConfirmation else { return false }
        return !send.isConfirmed
    }

    public var promptMessage: String? {
        guard let send = pendingSend, needsConfirmation else { return nil }
        return send.summary
    }
}

// MARK: - 508. 删除回收站保护 (DeleteTrashProtection)
// 确保删除操作经过回收站而非永久删除

public struct DeleteTrashProtection: Sendable, Codable, Equatable {
    public struct DeleteRequest: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var filePaths: [String]
        public var isDirectory: Bool
        public var totalSizeBytes: Int64
        public var protectionLevel: ProtectionLevel
        public var isMovedToTrash: Bool
        public var isConfirmed: Bool

        public enum ProtectionLevel: String, Sendable, Codable {
            case normal
            case protected
            case critical
        }

        public init(
            id: UUID = UUID(),
            filePaths: [String],
            isDirectory: Bool = false,
            totalSizeBytes: Int64 = 0,
            protectionLevel: ProtectionLevel = .normal,
            isMovedToTrash: Bool = false,
            isConfirmed: Bool = false
        ) {
            self.id = id
            self.filePaths = filePaths
            self.isDirectory = isDirectory
            self.totalSizeBytes = totalSizeBytes
            self.protectionLevel = protectionLevel
            self.isMovedToTrash = isMovedToTrash
            self.isConfirmed = isConfirmed
        }

        public var sizeFormatted: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSizeBytes)
        }

        public var summary: String {
            let type = isDirectory ? "文件夹" : "文件"
            let level = protectionLevel == .critical ? "⚠️ " : ""
            return "\(level)删除 \(filePaths.count) 个\(type)（\(sizeFormatted)）"
        }
    }

    public var pendingDelete: DeleteRequest?
    public var forceTrashOnly: Bool
    public var requireConfirmation: Bool

    public init(pendingDelete: DeleteRequest? = nil, forceTrashOnly: Bool = true, requireConfirmation: Bool = true) {
        self.pendingDelete = pendingDelete
        self.forceTrashOnly = forceTrashOnly
        self.requireConfirmation = requireConfirmation
    }

    public mutating func setPendingDelete(_ request: DeleteRequest) {
        pendingDelete = request
    }

    public mutating func confirm() {
        pendingDelete?.isConfirmed = true
        pendingDelete?.isMovedToTrash = forceTrashOnly
    }

    public mutating func reject() {
        pendingDelete = nil
    }

    public var needsConfirmation: Bool {
        guard let delete = pendingDelete, requireConfirmation else { return false }
        return !delete.isConfirmed
    }

    public var promptMessage: String? {
        guard let delete = pendingDelete, needsConfirmation else { return nil }
        var parts = [delete.summary]
        if forceTrashOnly {
            parts.append("将移至废纸篓（非永久删除）")
        }
        parts.append("是否确认？")
        return parts.joined(separator: "\n")
    }

    public var canExecute: Bool {
        guard let delete = pendingDelete else { return false }
        return delete.isConfirmed && (forceTrashOnly || delete.isMovedToTrash)
    }
}

// MARK: - 509. 数据脱敏引擎 (DataMaskingEngine)
// 对敏感数据进行自动脱敏

public struct DataMaskingEngine: Sendable, Codable, Equatable {
    public enum DataCategory: String, Sendable, Codable, CaseIterable {
        case email
        case phone
        case idCard
        case bankCard
        case password
        case apiKey
        case address
        case name
        case ipAddress
        case creditCard
        case custom

        public var maskPattern: String {
            switch self {
            case .email: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
            case .phone: #"1[3-9]\d{9}"#
            case .idCard: #"\d{17}[\dXx]"#
            case .bankCard: #"\d{16,19}"#
            case .password: #"(?i)(password|pwd|secret)\s*[:=]\s*\S+"#
            case .apiKey: #"(?i)(api[_-]?key|token|secret)\s*[:=]\s*\S+"#
            case .address: #"(?i)(地址|address|省|市|区|路|号|街道)\s*\S+"#
            case .name: #"\p{Lu}{2,4}"# // 简单英文名，中文名通过关键词
            case .ipAddress: #"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#
            case .creditCard: #"\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}"#
            case .custom: #""#
            }
        }
    }

    public var enabledCategories: Set<DataCategory>
    public var maskChar: String
    public var maskLength: Int
    public var lastMaskedCount: Int
    public var isEnabled: Bool

    public init(
        enabledCategories: Set<DataCategory> = [.email, .phone, .idCard, .bankCard, .password, .apiKey, .creditCard],
        maskChar: String = String("*"),
        maskLength: Int = 4,
        lastMaskedCount: Int = 0,
        isEnabled: Bool = true
    ) {
        self.enabledCategories = enabledCategories
        self.maskChar = maskChar
        self.maskLength = maskLength
        self.lastMaskedCount = lastMaskedCount
        self.isEnabled = isEnabled
    }

    public mutating func mask(_ text: String) -> String {
        guard isEnabled else { return text }
        var result = text
        var totalMasked = 0

        for category in enabledCategories {
            let pattern = category.maskPattern
            guard !pattern.isEmpty else { continue }
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = regex.matches(in: result, range: range)
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: result) else { continue }
                let matched = String(result[matchRange])
                let masked: String
                switch category {
                case .email:
                    let parts = matched.split(separator: "@", maxSplits: 1)
                    if let first = parts.first, let domain = parts.last {
                        let prefix = String(first.prefix(2)) + String(repeating: maskChar, count: max(0, first.count - 2))
                        masked = "\(prefix)@\(domain)"
                    } else {
                        masked = String(repeating: maskChar, count: matched.count)
                    }
                case .phone:
                    masked = String(matched.prefix(3)) + String(repeating: maskChar, count: 4) + String(matched.suffix(4))
                case .idCard:
                    masked = String(matched.prefix(6)) + String(repeating: maskChar, count: 8) + String(matched.suffix(4))
                case .bankCard, .creditCard:
                    let cleaned = matched.filter(\.isNumber)
                    masked = String(cleaned.prefix(4)) + String(repeating: maskChar, count: max(0, min(cleaned.count - 8, maskLength))) + String(cleaned.suffix(4))
                case .password:
                    masked = matched.components(separatedBy: "=").first.map { $0 + "=****" }
                        ?? String(repeating: maskChar, count: matched.count)
                case .apiKey:
                    let parts = matched.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let keyPrefix = parts[0] + "="
                        let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                        let visiblePrefix = String(value.prefix(3))
                        let maskedPart = String(repeating: maskChar, count: max(0, value.count - 3))
                        masked = keyPrefix + " " + visiblePrefix + maskedPart
                    } else {
                        masked = String(repeating: maskChar, count: matched.count)
                    }
                case .address, .name, .custom:
                    masked = matched.prefix(1) + String(repeating: maskChar, count: max(0, matched.count - 1))
                case .ipAddress:
                    masked = matched.components(separatedBy: ".").enumerated().map { i, octet in
                        i < 2 ? octet : "***"
                    }.joined(separator: ".")
                }
                result.replaceSubrange(matchRange, with: masked)
                totalMasked += 1
            }
        }

        lastMaskedCount = totalMasked
        return result
    }

    public mutating func maskSensitiveKeys(in dict: [String: String]) -> [String: String] {
        let sensitiveKeys = ["password", "secret", "token", "apiKey", "api_key", "privateKey", "auth", "credential"]
        var result = dict
        for key in dict.keys {
            if sensitiveKeys.contains(where: { key.localizedCaseInsensitiveContains($0) }) {
                result[key] = String(repeating: maskChar, count: min((dict[key]?.count ?? 4), 8))
            }
        }
        return result
    }
}

// MARK: - 510. 操作验证+截图证据 (OperationVerifier)
// 验证操作结果并保存截图证据

public struct OperationVerifier: Sendable, Codable, Equatable {
    public enum VerificationMethod: String, Sendable, Codable, CaseIterable {
        case screenshotCompare
        case elementExist
        case elementNotExist
        case textContains
        case stateChange
        case manual
    }

    public struct VerificationRecord: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var operationDescription: String
        public var method: VerificationMethod
        public var expectedResult: String
        public var actualResult: String
        public var passed: Bool
        public var screenshotBeforePath: String?
        public var screenshotAfterPath: String?
        public var verifiedAt: Date
        public var confidence: Double

        public init(
            id: UUID = UUID(),
            operationDescription: String,
            method: VerificationMethod,
            expectedResult: String,
            actualResult: String = "",
            passed: Bool = false,
            screenshotBeforePath: String? = nil,
            screenshotAfterPath: String? = nil,
            verifiedAt: Date = Date(),
            confidence: Double = 1.0
        ) {
            self.id = id
            self.operationDescription = operationDescription
            self.method = method
            self.expectedResult = expectedResult
            self.actualResult = actualResult
            self.passed = passed
            self.screenshotBeforePath = screenshotBeforePath
            self.screenshotAfterPath = screenshotAfterPath
            self.verifiedAt = verifiedAt
            self.confidence = confidence
        }

        public var summary: String {
            let icon = passed ? "✓" : "✗"
            return "\(icon) \(operationDescription)（\(method)）"
        }
    }

    public var records: [VerificationRecord]
    public var requireAllPass: Bool
    public var captureScreenshots: Bool

    public init(records: [VerificationRecord] = [], requireAllPass: Bool = false, captureScreenshots: Bool = true) {
        self.records = records
        self.requireAllPass = requireAllPass
        self.captureScreenshots = captureScreenshots
    }

    public mutating func addRecord(_ record: VerificationRecord) {
        records.append(record)
    }

    public var lastRecord: VerificationRecord? { records.last }
    public var allPassed: Bool { records.allSatisfy(\.passed) }
    public var passRate: Double {
        guard !records.isEmpty else { return 1.0 }
        return Double(records.filter(\.passed).count) / Double(records.count)
    }

    public var evidenceSummary: String {
        let passed = records.filter(\.passed).count
        let total = records.count
        let screenshots = records.compactMap(\.screenshotAfterPath).count
        return "验证：\(passed)/\(total) 通过，截图证据 \(screenshots) 张"
    }
}

// MARK: - 511. 心跳检测+自动恢复 (HeartbeatRecovery)
// 监控操作状态心跳，异常时自动恢复

public struct HeartbeatRecovery: Sendable, Codable, Equatable {
    public enum HeartbeatStatus: String, Sendable, Codable {
        case healthy
        case warning
        case critical
        case lost
    }

    public struct HeartbeatRecord: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var timestamp: Date
        public var status: HeartbeatStatus
        public var message: String

        public init(id: UUID = UUID(), timestamp: Date = Date(), status: HeartbeatStatus, message: String) {
            self.id = id
            self.timestamp = timestamp
            self.status = status
            self.message = message
        }
    }

    public var heartbeatInterval: TimeInterval
    public var warningThreshold: TimeInterval
    public var criticalThreshold: TimeInterval
    public var lastHeartbeat: Date
    public var heartbeatHistory: [HeartbeatRecord]
    public var autoRecoveryEnabled: Bool
    public var recoveryStrategy: RecoveryStrategy
    public var currentStatus: HeartbeatStatus

    public enum RecoveryStrategy: String, Sendable, Codable {
        case restart
        case retry
        case reset
        case notifyOnly
    }

    public init(
        heartbeatInterval: TimeInterval = 5,
        warningThreshold: TimeInterval = 15,
        criticalThreshold: TimeInterval = 30,
        lastHeartbeat: Date = Date(),
        heartbeatHistory: [HeartbeatRecord] = [],
        autoRecoveryEnabled: Bool = true,
        recoveryStrategy: RecoveryStrategy = .retry,
        currentStatus: HeartbeatStatus = .healthy
    ) {
        self.heartbeatInterval = heartbeatInterval
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        self.lastHeartbeat = lastHeartbeat
        self.heartbeatHistory = heartbeatHistory
        self.autoRecoveryEnabled = autoRecoveryEnabled
        self.recoveryStrategy = recoveryStrategy
        self.currentStatus = currentStatus
    }

    public mutating func beat() {
        lastHeartbeat = Date()
        currentStatus = .healthy
        heartbeatHistory.append(HeartbeatRecord(status: .healthy, message: "心跳正常"))
        if heartbeatHistory.count > 100 {
            heartbeatHistory.removeFirst(heartbeatHistory.count - 100)
        }
    }

    public mutating func check() -> HeartbeatStatus {
        let elapsed = Date().timeIntervalSince(lastHeartbeat)
        if elapsed >= criticalThreshold {
            currentStatus = .lost
            heartbeatHistory.append(HeartbeatRecord(status: .lost, message: "心跳丢失（\(Int(elapsed))秒无响应）"))
            if autoRecoveryEnabled {
                performAutoRecovery()
            }
            return .lost
        } else if elapsed >= warningThreshold {
            currentStatus = .warning
            heartbeatHistory.append(HeartbeatRecord(status: .warning, message: "心跳延迟（\(Int(elapsed))秒）"))
        } else {
            currentStatus = .healthy
        }
        return currentStatus
    }

    private mutating func performAutoRecovery() {
        let record = HeartbeatRecord(status: currentStatus, message: "自动恢复中（策略：\(recoveryStrategy.rawValue)）")
        heartbeatHistory.append(record)
        // 重置心跳，模拟恢复
        lastHeartbeat = Date()
        currentStatus = .healthy
    }

    public mutating func reset() {
        lastHeartbeat = Date()
        currentStatus = .healthy
    }

    public var isHealthy: Bool { currentStatus == .healthy }
    public var needsAttention: Bool { currentStatus == .lost || currentStatus == .critical }

    public var statusSummary: String {
        let elapsed = Date().timeIntervalSince(lastHeartbeat)
        let elapsedStr = String(format: "%.0f", elapsed)
        switch currentStatus {
        case .healthy: return "❤️ 运行正常"
        case .warning: return "💛 响应延迟（\(elapsedStr)s）"
        case .critical: return "🧡 响应异常（\(elapsedStr)s），即将恢复"
        case .lost: return "💔 失去响应（\(elapsedStr)s）\(autoRecoveryEnabled ? "，正在自动恢复" : "，需要人工干预")"
        }
    }
}

// MARK: - 512. 上下文摘要显示 (ContextSummary)
// 生成当前上下文摘要供用户查看

public struct ContextSummary: Sendable, Codable, Equatable {
    public struct SummaryItem: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var category: String
        public var content: String
        public var timestamp: Date

        public init(id: UUID = UUID(), category: String, content: String, timestamp: Date = Date()) {
            self.id = id
            self.category = category
            self.content = content
            self.timestamp = timestamp
        }
    }

    public var items: [SummaryItem]
    public var maxItems: Int

    public init(items: [SummaryItem] = [], maxItems: Int = 20) {
        self.items = items
        self.maxItems = maxItems
    }

    public mutating func addItem(category: String, content: String) {
        let item = SummaryItem(category: category, content: content)
        items.append(item)
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)
        }
    }

    public mutating func clear() {
        items.removeAll()
    }

    public func summaryByCategory() -> [String: [SummaryItem]] {
        Dictionary(grouping: items, by: \.category)
    }

    public func formatted() -> String {
        guard !items.isEmpty else { return "当前无上下文信息" }
        let groups = summaryByCategory()
        return groups.map { category, items in
            let itemStr = items.map { "  · \($0.content)" }.joined(separator: "\n")
            return "**\(category)**:\n\(itemStr)"
        }.joined(separator: "\n\n")
    }

    public func compactSummary() -> String {
        let latest = items.suffix(5)
        return latest.map(\.content).joined(separator: " → ")
    }

    public var isEmpty: Bool { items.isEmpty }
}

// MARK: - 513. 决策点用户确认 (DecisionPointConfirmation)
// 关键决策点需要用户确认

public struct DecisionPointConfirmation: Sendable, Codable, Equatable {
    public struct DecisionPoint: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var title: String
        public var description: String
        public var options: [DecisionOption]
        public var selectedOption: String?
        public var isDecided: Bool
        public var context: String
        public var requiredRole: String?

        public init(
            id: UUID = UUID(),
            title: String,
            description: String,
            options: [DecisionOption],
            selectedOption: String? = nil,
            isDecided: Bool = false,
            context: String = "",
            requiredRole: String? = nil
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.options = options
            self.selectedOption = selectedOption
            self.isDecided = isDecided
            self.context = context
            self.requiredRole = requiredRole
        }

        public var pendingPrompt: String {
            var parts: [String] = ["🤔 **需要您做决定**"]
            parts.append("")
            parts.append(title)
            parts.append(description)
            if !context.isEmpty {
                parts.append("")
                parts.append("背景：\(context)")
            }
            parts.append("")
            parts.append("请选择：")
            for option in options {
                parts.append("  \(option.label) — \(option.description)")
            }
            return parts.joined(separator: "\n")
        }
    }

    public struct DecisionOption: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var label: String
        public var description: String
        public var riskLevel: String
        public var isRecommended: Bool

        public init(id: UUID = UUID(), label: String, description: String, riskLevel: String = "low", isRecommended: Bool = false) {
            self.id = id
            self.label = label
            self.description = description
            self.riskLevel = riskLevel
            self.isRecommended = isRecommended
        }
    }

    public var pendingDecision: DecisionPoint?
    public var decisionHistory: [DecisionPoint]
    public var requireForHighRisk: Bool

    public init(pendingDecision: DecisionPoint? = nil, decisionHistory: [DecisionPoint] = [], requireForHighRisk: Bool = true) {
        self.pendingDecision = pendingDecision
        self.decisionHistory = decisionHistory
        self.requireForHighRisk = requireForHighRisk
    }

    public mutating func presentDecision(_ decision: DecisionPoint) {
        pendingDecision = decision
    }

    public mutating func selectOption(_ label: String) {
        pendingDecision?.selectedOption = label
        pendingDecision?.isDecided = true
        if let decision = pendingDecision {
            decisionHistory.append(decision)
        }
        pendingDecision = nil
    }

    public mutating func reject() {
        pendingDecision = nil
    }

    public var needsDecision: Bool {
        guard let decision = pendingDecision else { return false }
        return !decision.isDecided
    }

    public var prompt: String? {
        pendingDecision?.pendingPrompt
    }
}

// MARK: - 514. 操作队列+冲突检测 (OperationQueue)
// 管理操作队列并检测冲突

public struct OperationQueue: Sendable, Codable, Equatable {
    public struct QueuedOperation: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var name: String
        public var targetApp: String?
        public var targetWindow: String?
        public var operationType: String
        public var priority: Int
        public var createdAt: Date
        public var status: QueueStatus
        public var dependsOn: [UUID]

        public enum QueueStatus: String, Sendable, Codable {
            case queued
            case executing
            case completed
            case failed
            case cancelled
            case blocked
        }

        public init(
            id: UUID = UUID(),
            name: String,
            targetApp: String? = nil,
            targetWindow: String? = nil,
            operationType: String,
            priority: Int = 0,
            createdAt: Date = Date(),
            status: QueueStatus = .queued,
            dependsOn: [UUID] = []
        ) {
            self.id = id
            self.name = name
            self.targetApp = targetApp
            self.targetWindow = targetWindow
            self.operationType = operationType
            self.priority = priority
            self.createdAt = createdAt
            self.status = status
            self.dependsOn = dependsOn
        }

        public var conflictIdentifier: String {
            "\(targetApp ?? "")|\(targetWindow ?? "")|\(operationType)"
        }
    }

    public struct OperationConflict: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var operationA: UUID
        public var operationB: UUID
        public var conflictType: ConflictType
        public var description: String

        public enum ConflictType: String, Sendable, Codable {
            case sameTarget
            case sameApp
            case sameWindow
            case incompatibleTypes
            case resourceContention
        }

        public init(
            id: UUID = UUID(),
            operationA: UUID,
            operationB: UUID,
            conflictType: ConflictType,
            description: String
        ) {
            self.id = id
            self.operationA = operationA
            self.operationB = operationB
            self.conflictType = conflictType
            self.description = description
        }
    }

    public var operations: [QueuedOperation]
    public var conflicts: [OperationConflict]
    public var maxConcurrent: Int
    public var autoResolveConflicts: Bool

    public init(operations: [QueuedOperation] = [], conflicts: [OperationConflict] = [], maxConcurrent: Int = 1, autoResolveConflicts: Bool = true) {
        self.operations = operations
        self.conflicts = conflicts
        self.maxConcurrent = maxConcurrent
        self.autoResolveConflicts = autoResolveConflicts
    }

    public mutating func enqueue(_ operation: QueuedOperation) {
        operations.append(operation)
        detectConflicts(for: operation)
    }

    public mutating func detectConflicts(for operation: QueuedOperation) {
        for existing in operations where existing.id != operation.id && existing.status == .queued {
            if existing.conflictIdentifier == operation.conflictIdentifier {
                let conflict = OperationConflict(
                    operationA: existing.id,
                    operationB: operation.id,
                    conflictType: .sameTarget,
                    description: "\(existing.name) 与 \(operation.name) 操作同一目标"
                )
                conflicts.append(conflict)
            }
        }
        if autoResolveConflicts {
            resolveConflicts()
        }
    }

    public mutating func resolveConflicts() {
        for conflict in conflicts {
            guard let opA = operations.first(where: { $0.id == conflict.operationA }),
                  let opB = operations.first(where: { $0.id == conflict.operationB }) else { continue }
            // 优先级高的保留，低的标记为阻塞
            if opA.priority >= opB.priority {
                if let idx = operations.firstIndex(where: { $0.id == opB.id }) {
                    operations[idx].status = .blocked
                }
            } else {
                if let idx = operations.firstIndex(where: { $0.id == opA.id }) {
                    operations[idx].status = .blocked
                }
            }
        }
        conflicts.removeAll()
    }

    public mutating func complete(_ id: UUID) {
        guard let idx = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[idx].status = .completed
        // 唤醒依赖此操作的任务
        for i in operations.indices where operations[i].dependsOn.contains(id) && operations[i].status == .blocked {
            operations[i].status = .queued
        }
    }

    public mutating func cancel(_ id: UUID) {
        guard let idx = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[idx].status = .cancelled
    }

    public mutating func fail(_ id: UUID, error: String) {
        guard let idx = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[idx].status = .failed
    }

    public var nextOperation: QueuedOperation? {
        operations.filter { $0.status == .queued }.min { $0.priority > $1.priority }
    }

    public var activeCount: Int {
        operations.filter { $0.status == .executing }.count
    }

    public var canAcceptMore: Bool { activeCount < maxConcurrent }

    public var queueSummary: String {
        let queued = operations.filter { $0.status == .queued }.count
        let executing = operations.filter { $0.status == .executing }.count
        let completed = operations.filter { $0.status == .completed }.count
        let blocked = operations.filter { $0.status == .blocked }.count
        return "队列：\(queued)待执行 | \(executing)执行中 | \(completed)已完成 | \(blocked)阻塞"
    }
}

// MARK: - 515. 操作日志+回放 (OperationLogReplay)
// 记录操作日志并支持回放

public struct OperationLogReplay: Sendable, Codable, Equatable {
    public struct LogEntry: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var timestamp: Date
        public var action: String
        public var targetDescription: String
        public var result: String
        public var durationMs: Double
        public var success: Bool
        public var detail: String
        public var screenshotPath: String?

        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            action: String,
            targetDescription: String,
            result: String = "",
            durationMs: Double = 0,
            success: Bool = true,
            detail: String = "",
            screenshotPath: String? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.action = action
            self.targetDescription = targetDescription
            self.result = result
            self.durationMs = durationMs
            self.success = success
            self.detail = detail
            self.screenshotPath = screenshotPath
        }

        public var summary: String {
            let icon = success ? "✓" : "✗"
            let time = ISO8601DateFormatter().string(from: timestamp).suffix(12)
            return "\(time) \(icon) \(action) \(targetDescription) (\(String(format: "%.0f", durationMs))ms)"
        }
    }

    public var entries: [LogEntry]
    public var maxEntries: Int
    public var sessionStart: Date
    public var sessionLabel: String

    public init(entries: [LogEntry] = [], maxEntries: Int = 1000, sessionStart: Date = Date(), sessionLabel: String = "") {
        self.entries = entries
        self.maxEntries = maxEntries
        self.sessionStart = sessionStart
        self.sessionLabel = sessionLabel
    }

    public mutating func record(action: String, targetDescription: String, result: String = "", durationMs: Double = 0, success: Bool = true, detail: String = "", screenshot: String? = nil) {
        let entry = LogEntry(
            action: action,
            targetDescription: targetDescription,
            result: result,
            durationMs: durationMs,
            success: success,
            detail: detail,
            screenshotPath: screenshot
        )
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func filter(byAction: String) -> [LogEntry] {
        entries.filter { $0.action.localizedCaseInsensitiveContains(byAction) }
    }

    public func filter(successOnly: Bool) -> [LogEntry] {
        entries.filter { $0.success == successOnly }
    }

    public func filter(dateRange: ClosedRange<Date>) -> [LogEntry] {
        entries.filter { dateRange.contains($0.timestamp) }
    }

    public var recentEntries: [LogEntry] {
        Array(entries.suffix(20).reversed())
    }

    public var successRate: Double {
        guard !entries.isEmpty else { return 1.0 }
        return Double(entries.filter(\.success).count) / Double(entries.count)
    }

    public var totalDurationMs: Double {
        entries.reduce(0) { $0 + $1.durationMs }
    }

    public func textExport() -> String {
        var lines: [String] = ["操作日志 - \(sessionLabel)"]
        lines.append("会话开始：\(ISO8601DateFormatter().string(from: sessionStart))")
        lines.append("总操作数：\(entries.count)")
        lines.append("成功率：\(Int(successRate * 100))%")
        lines.append("总耗时：\(String(format: "%.1f", totalDurationMs / 1000))s")
        lines.append(String(repeating: "-", count: 40))
        for entry in entries {
            lines.append(entry.summary)
            if !entry.detail.isEmpty {
                lines.append("  \(entry.detail)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public var groupByAction: [String: [LogEntry]] {
        Dictionary(grouping: entries) { $0.action }
    }

    public var groupByTarget: [String: [LogEntry]] {
        Dictionary(grouping: entries) { $0.targetDescription }
    }

    public mutating func clear() {
        entries.removeAll()
    }
}
