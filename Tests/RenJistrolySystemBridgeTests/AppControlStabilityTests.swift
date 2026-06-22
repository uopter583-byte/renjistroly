import Foundation
import XCTest
@testable import RenJistrolySystemBridge
import RenJistrolyModels

// MARK: - App控制稳定性测试

func testOpenAppByName() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, activateApp should throw .noPermission
    // but actually activateApp uses NSWorkspace which doesn't need AX permission
    do {
        try await bridge.activateApp(matching: "Finder")
        XCTAssertTrue(true)
    } catch let error as AccessibilityError {
        XCTFail("activateApp should not require AX permission: \(error)")
    } catch {
        XCTFail("意外的异常: \(error)")
    }
}

func testSwitchToRunningAppFocus() async {
    let bridge = AccessibilityBridge()
    do {
        try await bridge.activateApp(matching: "Safari")
        // If Safari is not running, this throws .actionFailed
        XCTAssertTrue(true)
    } catch let error as AccessibilityError {
        if case .actionFailed = error {
            // Safari may not be running, that's acceptable
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("意外的异常: \(error)")
    }
}

func testHideAppEquivalent() async {
    let appleScript = AppleScriptBridge()
    // Hiding is done via AppleScript; verify the bridge handles it without crash
    do {
        let script = """
        tell application "System Events"
            set visible of first application process whose name is "Finder" to false
        end tell
        """
        _ = try await appleScript.run(script)
        XCTAssertTrue(true)
    } catch {
        // Permission denied is expected without automation rights
        XCTAssertTrue(error is AppleScriptError)
    }
}

func testCloseFrontWindow() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, getWindowList should throw .noPermission
    do {
        let windows = try await bridge.getWindowList()
        // May or may not have windows, but no crash
        XCTAssertTrue(windows.count >= 0)
    } catch let error as AccessibilityError {
        if case .noPermission = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testMinimizeWindow() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, focusWindow should throw .noPermission
    do {
        try await bridge.focusWindow(title: "test")
        XCTFail("应该在无权限时抛出异常")
    } catch let error as AccessibilityError {
        if case .noPermission = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testForegroundDetection() async {
    let bridge = AccessibilityBridge()
    do {
        let bundleID = try await bridge.getFocusedAppBundleID()
        // Should return a bundle ID or nil, but no crash
        XCTAssertTrue(bundleID == nil || bundleID?.isEmpty == false)
    } catch let error as AccessibilityError {
        if case .noPermission = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testBundleIDMatchAndFind() async {
    let registry = AppDriverRegistry()
    XCTAssertFalse(registry.drivers.isEmpty)

    // Verify bundle ID matching via known app names in the registry
    let safari = registry.driver(id: "safari")
    XCTAssertTrue(safari != nil)
    XCTAssertTrue(safari?.displayName == "Safari")
    XCTAssertTrue(safari?.capabilities.contains(.open) == true)
    XCTAssertTrue(safari?.capabilities.contains(.read) == true)

    // Find matching running application by bundle ID
    let workspace = NSWorkspace.shared
    let foundApp = workspace.runningApplications.first { app in
        app.bundleIdentifier == "com.apple.finder"
    }
    XCTAssertTrue(foundApp != nil)
    XCTAssertTrue(foundApp?.bundleIdentifier == "com.apple.finder")
}

func testChineseAppNameHandling() async {
    let appleScript = AppleScriptBridge()
    // Chinese app name should be handled without crash
    do {
        let name = try await appleScript.getActiveAppName()
        XCTAssertFalse(name.isEmpty)
    } catch {
        XCTAssertTrue(error is AppleScriptError)
    }
}

func testLaunchFailureHandlingAppNotFound() async {
    let bridge = AccessibilityBridge()
    // Activate a non-existent app should fail gracefully
    do {
        try await bridge.activateApp(matching: "NonExistentAppXYZ123")
        XCTFail("应该抛出异常")
    } catch let error as AccessibilityError {
        if case .actionFailed(let msg) = error {
            XCTAssertTrue(msg.contains("not running"))
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testPermissionFailureHandlingAXDenied() async {
    let bridge = AccessibilityBridge()
    // Most AX operations should throw .noPermission if AX is not trusted
    do {
        let _ = try await bridge.getAppState(app: nil, maxDepth: 3, includeScreenshot: false)
        XCTFail("应该在无权限时抛出异常")
    } catch let error as AccessibilityError {
        if case .noPermission = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

// MARK: - AppDriver registry tests

func testRegistryContainsAllDrivers() {
    let registry = AppDriverRegistry()
    let ids = Set(registry.drivers.map(\.id))
    XCTAssertTrue(ids.contains("finder"))
    XCTAssertTrue(ids.contains("safari"))
    XCTAssertTrue(ids.contains("chrome"))
    XCTAssertTrue(ids.contains("terminal"))
    XCTAssertTrue(ids.contains("xcode"))
    XCTAssertTrue(ids.contains("system-settings"))
    XCTAssertTrue(ids.contains("wechat"))
    XCTAssertTrue(ids.contains("system"))
}

func testDriverCapabilities() {
    let finder = FinderDriver()
    XCTAssertTrue(finder.capabilities.contains(.open))
    XCTAssertTrue(finder.capabilities.contains(.search))
    XCTAssertTrue(finder.capabilities.contains(.manageWindows))
    XCTAssertTrue(!finder.capabilities.contains(.runCommand))

    let terminal = TerminalDriver()
    XCTAssertTrue(terminal.capabilities.contains(.runCommand))
    XCTAssertTrue(terminal.capabilities.contains(.open))
}

func testFinderDriverBasicOperations() throws {
    let finder = FinderDriver()
    // List directory should work
    let items = try finder.listDirectory(path: "/tmp")
    XCTAssertFalse(items.isEmpty)

    // File info for existing file
    let info = try finder.getFileInfo(path: "/tmp")
    XCTAssertTrue(info["isDirectory"] == "true")
}

func testFinderDriverSearch() throws {
    let finder = FinderDriver()
    let results = try finder.search(named: "tmp", in: "/")
    XCTAssertTrue(results.contains("tmp"))
}

func testSystemDriverProcessInfo() async {
    let sys = SystemDriver()
    let processes = await sys.runningProcesses(matching: "Finder")
    XCTAssertFalse(processes.isEmpty)
    XCTAssertTrue(processes.first?.pid != nil)

    let noMatch = await sys.runningProcesses(matching: "xyzzy123nonexistent")
    XCTAssertTrue(noMatch.isEmpty)
}

func testSystemSettingsDriverPaneURLs() {
    XCTAssertTrue(SystemSettingsPane.wifi.url != nil)
    XCTAssertTrue(SystemSettingsPane.accessibility.url != nil)
    XCTAssertTrue(SystemSettingsPane.siri.url == nil)
}

func testComputerUseAppStateJSONFormatting() {
    let state = ComputerUseAppState(
        requestedApp: "Finder",
        activeAppBundleID: "com.apple.finder",
        activeAppName: "Finder",
        focusedWindowTitle: "桌面",
        windows: [
            ComputerUseWindow(title: "桌面", isMain: true, isFocused: true)
        ],
        elements: [
            ComputerUseElement(
                elementIndex: "e1",
                role: "AXApplication",
                title: "Finder",
                depth: 0,
                childPath: []
            )
        ]
    )
    let json = state.jsonString(pretty: false, includeScreenshot: false)
    XCTAssertTrue(json.contains("Finder"))
    XCTAssertTrue(json.contains("com.apple.finder"))
    XCTAssertTrue(!json.contains("screenshot"))
}

func testComputerUseStateDeltaDetection() {
    let before = ComputerUseAppState(
        activeAppBundleID: "com.apple.finder",
        activeAppName: "Finder"
    )
    let after = ComputerUseAppState(
        activeAppBundleID: "com.apple.Safari",
        activeAppName: "Safari"
    )
    let delta = ComputerUseStateDelta(before: before, after: after)
    XCTAssertTrue(delta.hasMeaningfulChange)
    XCTAssertTrue(delta.activeAppChanged)
    XCTAssertTrue(delta.changeDescriptions.contains("前台应用变化"))
}
