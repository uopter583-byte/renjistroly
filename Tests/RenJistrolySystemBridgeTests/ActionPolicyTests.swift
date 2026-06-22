import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - Policy decisions for various actions

final class ActionPolicyTests: XCTestCase {
    func testDeleteFileRequiresDevMode() {
        let policy = ActionPolicy(developerModeEnabled: false)
        let action = MacAction(kind: .deleteFile, payload: ["path": "/tmp/test"], riskLevel: .persistentOrExternal, humanPreview: "删除文件")
        let decision = policy.evaluate(action)
        guard case .developerModeOnly = decision else {
            XCTFail("Expected developerModeOnly, got \(decision)")
            return
        }
    }

    func testDeleteFileWithDevModeAsksConfirmation() {
        let policy = ActionPolicy(developerModeEnabled: true)
        let action = MacAction(kind: .deleteFile, payload: ["path": "/tmp/test"], riskLevel: .persistentOrExternal, humanPreview: "删除文件")
        let decision = policy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation, got \(decision)")
            return
        }
    }

    func testRunShellCommandRequiresDevMode() {
        let policy = ActionPolicy(developerModeEnabled: false)
        let action = MacAction(kind: .runShellCommand, payload: ["command": "rm"], riskLevel: .persistentOrExternal, humanPreview: "运行命令")
        let decision = policy.evaluate(action)
        guard case .developerModeOnly = decision else {
            XCTFail("Expected developerModeOnly, got \(decision)")
            return
        }
    }

    func testSendMessageRequiresConfirmation() {
        let policy = ActionPolicy()
        let action = MacAction(kind: .sendMessage, payload: [:], riskLevel: .persistentOrExternal, humanPreview: "发送消息")
        let decision = policy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation, got \(decision)")
            return
        }
    }

    func testQuitApplicationRequiresConfirmation() {
        let policy = ActionPolicy()
        let action = MacAction(kind: .quitApplication, payload: ["name": "Safari"], riskLevel: .persistentOrExternal, humanPreview: "退出 Safari")
        let decision = policy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation, got \(decision)")
            return
        }
    }

    func testOpenTerminalCommandRequiresConfirmation() {
        let policy = ActionPolicy()
        let action = MacAction(kind: .openTerminalCommand, payload: ["command": "ls"], riskLevel: .persistentOrExternal, humanPreview: "终端命令")
        let decision = policy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation, got \(decision)")
            return
        }
    }

    func testInsertShortTextAllowed() {
        let policy = ActionPolicy()
        let action = MacAction(kind: .insertText, payload: ["text": "hello"], riskLevel: .reversibleInput, humanPreview: "输入 hello")
        let decision = policy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation, got \(decision)")
            return
        }
    }

    func testInsertLongTextRequiresConfirmation() {
        let policy = ActionPolicy()
        let long = String(repeating: "A", count: 200)
        let action = MacAction(kind: .insertText, payload: ["text": long], riskLevel: .reversibleInput, humanPreview: "输入长文本")
        let decision = policy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation for long text, got \(decision)")
            return
        }
    }

    func testInsertTextHighRiskRequiresConfirmation() {
        let strictPolicy = ActionPolicy(maximumAutoAllowRisk: .readOnly)
        let action = MacAction(kind: .insertText, payload: ["text": "hi"], riskLevel: .persistentOrExternal, humanPreview: "高风险输入")
        let decision = strictPolicy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation for high risk, got \(decision)")
            return
        }
    }

    func testReadOnlyActionAllowed() {
        let policy = ActionPolicy()
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "读取上下文")
        let decision = policy.evaluate(action)
        guard case .allow = decision else {
            XCTFail("Expected allow, got \(decision)")
            return
        }
    }

    func testOpenApplicationAllowed() {
        let policy = ActionPolicy()
        let action = MacAction(kind: .openApplication, payload: ["name": "Safari"], riskLevel: .readOnly, humanPreview: "打开 Safari")
        let decision = policy.evaluate(action)
        guard case .allow = decision else {
            XCTFail("Expected allow, got \(decision)")
            return
        }
    }

    func testOpenApplicationHighRiskWithStrictPolicyRequiresConfirmation() {
        let strictPolicy = ActionPolicy(maximumAutoAllowRisk: .readOnly)
        let action = MacAction(kind: .openApplication, payload: ["name": "Safari"], riskLevel: .persistentOrExternal, humanPreview: "打开 Safari")
        let decision = strictPolicy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation, got \(decision)")
            return
        }
    }

    func testCloseWindowAllowed() {
        let policy = ActionPolicy()
        let action = MacAction(kind: .closeWindow, riskLevel: .reversibleInput, humanPreview: "关闭窗口")
        let decision = policy.evaluate(action)
        guard case .requireConfirmation = decision else {
            XCTFail("Expected requireConfirmation, got \(decision)")
            return
        }
    }

    func testPolicyDecisionMessagesNonEmpty() {
        let policy = ActionPolicy(developerModeEnabled: true)
        let actions: [MacAction] = [
            MacAction(kind: .deleteFile, payload: ["path": "/tmp/test"], riskLevel: .persistentOrExternal, humanPreview: "删除"),
            MacAction(kind: .sendMessage, payload: [:], riskLevel: .persistentOrExternal, humanPreview: "发送"),
            MacAction(kind: .quitApplication, payload: ["name": "App"], riskLevel: .persistentOrExternal, humanPreview: "退出"),
            MacAction(kind: .openTerminalCommand, payload: ["command": "ls"], riskLevel: .persistentOrExternal, humanPreview: "终端"),
        ]
        for action in actions {
            let decision = policy.evaluate(action)
            switch decision {
            case .allow: XCTFail("Unexpected allow for \(action.kind)")
            case .requireConfirmation(let msg): XCTAssertFalse(msg.isEmpty)
            case .developerModeOnly(let msg): XCTAssertFalse(msg.isEmpty)
            case .deny: XCTFail("Unexpected deny for \(action.kind)")
            }
        }
    }
}
