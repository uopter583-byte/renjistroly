import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

@MainActor
public final class DesktopContextCollector {
    private let accessibilityBridge: AccessibilityBridge
    private let appleScriptBridge: AppleScriptBridge

    public init(
        accessibilityBridge: AccessibilityBridge = AccessibilityBridge(),
        appleScriptBridge: AppleScriptBridge = AppleScriptBridge()
    ) {
        self.accessibilityBridge = accessibilityBridge
        self.appleScriptBridge = appleScriptBridge
    }

    public func collect(projectContext: ProjectContext? = nil) async -> DesktopContext {
        async let activeAppBundleID = getActiveAppBundleID()
        async let activeAppName = getActiveAppName()
        async let focusedWindowTitle = getFocusedWindowTitle()
        async let focusedElementRole = getFocusedElementRole()
        async let focusedElementValue = getFocusedElementValue()
        async let selectedText = getSelectedText()
        async let browserPageState = getBrowserPageState()
        async let finderWindowState = getFinderWindowState()
        async let windows = getWindows()
        async let uiElements = getUIElements()

        return await DesktopContext(
            activeAppBundleID: activeAppBundleID,
            activeAppName: activeAppName,
            focusedWindowTitle: focusedWindowTitle,
            focusedElementRole: focusedElementRole,
            focusedElementValue: focusedElementValue,
            selectedText: selectedText,
            browserPageState: browserPageState,
            finderWindowState: finderWindowState,
            windows: windows,
            uiElements: uiElements,
            projectContext: projectContext
        )
    }

    private func getActiveAppBundleID() async -> String? {
        try? await accessibilityBridge.getFocusedAppBundleID()
    }

    private func getActiveAppName() async -> String? {
        try? await appleScriptBridge.getActiveAppName()
    }

    private func getFocusedWindowTitle() async -> String? {
        try? await accessibilityBridge.getFocusedWindowTitle()
    }

    private func getFocusedElementRole() async -> String? {
        try? await accessibilityBridge.getElementRole()
    }

    private func getFocusedElementValue() async -> String? {
        try? await accessibilityBridge.getFocusedValue()
    }

    private func getSelectedText() async -> String? {
        try? await accessibilityBridge.getSelectedText()
    }

    private func getBrowserPageState() async -> BrowserPageState? {
        guard let activeAppName = try? await appleScriptBridge.getActiveAppName() else {
            return nil
        }

        if activeAppName.localizedCaseInsensitiveContains("Safari") {
            return try? await SafariDriver(appleScriptBridge: appleScriptBridge).currentPageState()
        }
        if activeAppName.localizedCaseInsensitiveContains("Chrome") {
            return try? await ChromeDriver(appleScriptBridge: appleScriptBridge).currentPageState()
        }
        return nil
    }

    private func getFinderWindowState() async -> FinderWindowState? {
        guard let activeAppName = try? await appleScriptBridge.getActiveAppName(),
              activeAppName.localizedCaseInsensitiveContains("Finder") else {
            return nil
        }
        return try? await FinderDriver(appleScriptBridge: appleScriptBridge).currentWindowState()
    }

    private func getWindows() async -> [DesktopWindow] {
        let titles = (try? await accessibilityBridge.getWindowList()) ?? []
        return titles.map { DesktopWindow(title: $0) }
    }

    private func getUIElements() async -> [DesktopUIElement] {
        let nodes = (try? await accessibilityBridge.getUIElementTree(maxDepth: 3)) ?? []
        return nodes.map {
            DesktopUIElement(
                role: $0.role,
                title: $0.title,
                description: $0.description,
                depth: $0.depth
            )
        }
    }
}
