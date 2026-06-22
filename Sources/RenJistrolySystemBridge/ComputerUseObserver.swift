import Foundation
import RenJistrolyModels

public actor ComputerUseObserver {
    private let accessibility: AccessibilityContextProvider
    private let screen: ScreenContextProvider

    public init(accessibility: AccessibilityContextProvider, screen: ScreenContextProvider) {
        self.accessibility = accessibility
        self.screen = screen
    }

    public func observe(includeOCR: Bool = true, skipOwnWindows: Bool = false) async -> ComputerUseObservation {
        async let frontmost = accessibility.readFrontmostApp()
        async let runningApps = accessibility.readRunningApps()
        async let focused = accessibility.readFocusedElement()
        async let accessibilityTargets = accessibility.readFrontmostAccessibilityTargets()
        async let screenContext = screen.captureCurrentScreen(includeImageData: includeOCR, skipOwnWindows: skipOwnWindows)
        async let compactTree = await accessibility.compactAccessibilityTree(limit: 40, appBundleID: nil)

        let app = await frontmost
        let apps = await runningApps
        let element = await focused
        let axTargets = await accessibilityTargets
        let screen = await screenContext
        let targets = buildTargets(app: app, runningApps: apps, focused: element, accessibilityTargets: axTargets, screen: screen)

        return ComputerUseObservation(
            frontmostApp: app,
            runningApps: apps,
            visibleWindows: screen.visibleWindows,
            focusedElement: element,
            ocrText: screen.recognizedText,
            targets: targets,
            compactAXTree: await compactTree
        )
    }

    private func buildTargets(
        app: AppContext?,
        runningApps: [RunningAppContext],
        focused: UIElementContext?,
        accessibilityTargets: [ComputerUseTarget],
        screen: ScreenContext
    ) -> [ComputerUseTarget] {
        var targets: [ComputerUseTarget] = []

        for runningApp in runningApps {
            targets.append(
                ComputerUseTarget(
                    kind: .runningApp,
                    label: runningApp.appName,
                    owner: runningApp.bundleIdentifier,
                    confidence: runningApp.isFrontmost ? 0.95 : 0.75
                )
            )
        }

        for window in screen.visibleWindows {
            targets.append(
                ComputerUseTarget(
                    kind: .window,
                    label: window.windowTitle.flatMap { $0.isEmpty ? nil : $0 } ?? window.ownerName,
                    owner: window.ownerName,
                    boundsDescription: window.boundsDescription,
                    confidence: 0.7
                )
            )
        }

        if let focused {
            let label = focused.title ?? focused.selectedText ?? focused.value ?? focused.role ?? "焦点控件"
            targets.append(
                ComputerUseTarget(
                    kind: .accessibilityElement,
                    label: label,
                    owner: app?.appName,
                    role: focused.role,
                    confidence: 0.8
                )
            )
        }

        targets.append(contentsOf: accessibilityTargets)

        if let ocrText = screen.recognizedText {
            for line in ocrText.split(separator: "\n").prefix(40) {
                let label = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty else { continue }
                targets.append(
                    ComputerUseTarget(
                        kind: .ocrText,
                        label: label,
                        confidence: 0.45
                    )
                )
            }
        }

        return targets
    }
}
