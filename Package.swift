// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RenJistroly",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "RenJistrolyModels", targets: ["RenJistrolyModels"]),
        .library(name: "RenJistrolySystemBridge", targets: ["RenJistrolySystemBridge"]),
        .library(name: "RenJistrolyCapability", targets: ["RenJistrolyCapability"]),
        .library(name: "RenJistrolyIntelligence", targets: ["RenJistrolyIntelligence"]),
        .library(name: "RenJistrolyEnterprise", targets: ["RenJistrolyEnterprise"]),
        .library(name: "RenJistrolyProductIdentity", targets: ["RenJistrolyProductIdentity"]),
        .library(name: "RenJistrolyConversation", targets: ["RenJistrolyConversation"]),
        .library(name: "RenJistrolyUI", targets: ["RenJistrolyUI"]),
        .executable(name: "RenJistroly", targets: ["RenJistroly"]),
        .executable(name: "RenJistrolyMCP", targets: ["RenJistrolyMCP"]),
        .executable(name: "RenJistrolyBridge", targets: ["RenJistrolyBridge"]),
        .executable(name: "RenJistrolyGate", targets: ["RenJistrolyGate"]),
        .executable(name: "RenJistrolyHelper", targets: ["RenJistrolyHelper"]),
    ],
    targets: [
        // MARK: - C wrapper for onnxruntime
        // Dev: links against Homebrew. Distribution: package_app.sh copies dylib into .app bundle.
        .target(
            name: "COrt",
            path: "Sources/COrt",
            cSettings: [.unsafeFlags(["-I/opt/homebrew/include"])],
            linkerSettings: [
                .unsafeFlags([
                    "-L/opt/homebrew/lib",
                    "-lonnxruntime",
                ])
            ]
        ),

        // MARK: - XPC Shared Protocol (no deps)
        .target(
            name: "RenJistrolyXPC",
            path: "Sources/RenJistrolyXPC"
        ),

        // MARK: - Executable
        .executableTarget(
            name: "RenJistroly",
            dependencies: [
                "RenJistrolyUI",
                "RenJistrolyConversation",
                "RenJistrolyIntelligence",
                "RenJistrolyCapability",
                "RenJistrolySystemBridge",
                "RenJistrolyModels",
                "RenJistrolyEnterprise",
                "RenJistrolyProductIdentity",
            ],
            path: "Sources/RenJistrolyApp",
            resources: [.process("Resources")]
        ),

        // MARK: - Bridge CLI (Claude Code integration: click, type, observe, open-app)
        .executableTarget(
            name: "RenJistrolyBridge",
            dependencies: ["RenJistrolyModels", "RenJistrolySystemBridge"],
            path: "Sources/RenJistrolyBridge"
        ),

        // MARK: - Gate relay (speech relay between App and Claude Code session)
        .executableTarget(
            name: "RenJistrolyGate",
            path: "Sources/RenJistrolyGate"
        ),

        // MARK: - MCP Server (stdio MCP protocol, exposes all real tools for Claude Code)
        .executableTarget(
            name: "RenJistrolyMCP",
            dependencies: [
                "RenJistrolyCapability",
                "RenJistrolySystemBridge",
                "RenJistrolyModels",
            ],
            path: "Sources/RenJistrolyMCP"
        ),

        // MARK: - Privileged Helper (SMJobBless)
        .executableTarget(
            name: "RenJistrolyHelper",
            dependencies: ["RenJistrolyXPC"],
            path: "Sources/RenJistrolyHelper",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__launchd_plist",
                    "-Xlinker", "HelperConfig/com.renjistroly.helper.plist",
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "HelperConfig/Info.plist",
                ]),
            ]
        ),

        // MARK: - Data Models (no internal deps)
        .target(
            name: "RenJistrolyModels",
            path: "Sources/RenJistrolyModels"
        ),

        // MARK: - Enterprise Layer (depends on Models)
        .target(
            name: "RenJistrolyEnterprise",
            dependencies: ["RenJistrolyModels"],
            path: "Sources/RenJistrolyEnterprise"
        ),

        // MARK: - Product Identity (depends on Models)
        .target(
            name: "RenJistrolyProductIdentity",
            dependencies: ["RenJistrolyModels"],
            path: "Sources/RenJistrolyProductIdentity"
        ),

        // MARK: - System Bridge (depends on Models for protocols)
        .target(
            name: "RenJistrolySystemBridge",
            dependencies: ["COrt", "RenJistrolyModels", "RenJistrolyXPC"],
            path: "Sources/RenJistrolySystemBridge",
            resources: [.copy("Resources")]
        ),

        // MARK: - Intelligence Layer (depends on Capability, Models)
        .target(
            name: "RenJistrolyIntelligence",
            dependencies: ["RenJistrolyCapability", "RenJistrolyModels", "RenJistrolySystemBridge"],
            path: "Sources/RenJistrolyIntelligence"
        ),

        // MARK: - Capability Layer (depends on SystemBridge, Models)
        .target(
            name: "RenJistrolyCapability",
            dependencies: ["RenJistrolySystemBridge", "RenJistrolyModels"],
            path: "Sources/RenJistrolyCapability"
        ),

        // MARK: - Conversation Engine (depends on Models, Capability, Intelligence, SystemBridge)
        .target(
            name: "RenJistrolyConversation",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolyCapability",
                "RenJistrolyIntelligence",
                "RenJistrolySystemBridge",
                "RenJistrolyProductIdentity",
            ],
            path: "Sources/RenJistrolyConversation"
        ),

        // MARK: - UI Layer (depends on Models, Conversation, Intelligence)
        .target(
            name: "RenJistrolyUI",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolyConversation",
                "RenJistrolyIntelligence",
            ],
            path: "Sources/RenJistrolyUI"
        ),

        // MARK: - Tests
        .testTarget(
            name: "RenJistrolyModelsTests",
            dependencies: ["RenJistrolyModels", "RenJistrolyConversation", "RenJistrolyEnterprise"],
            path: "Tests/RenJistrolyModelsTests"
        ),
        .testTarget(
            name: "RenJistrolySystemBridgeTests",
            dependencies: ["RenJistrolySystemBridge", "RenJistrolyModels"],
            path: "Tests/RenJistrolySystemBridgeTests"
        ),
        .testTarget(
            name: "RenJistrolyIntelligenceTests",
            dependencies: [
                "RenJistrolyIntelligence",
                "RenJistrolyModels",
                "RenJistrolySystemBridge",
                "RenJistrolyConversation",
            ],
            path: "Tests/RenJistrolyIntelligenceTests"
        ),
        .testTarget(
            name: "RenJistrolyCapabilityTests",
            dependencies: ["RenJistrolyCapability", "RenJistrolyModels", "RenJistrolySystemBridge"],
            path: "Tests/RenJistrolyCapabilityTests"
        ),
        .testTarget(
            name: "RenJistrolyConversationTests",
            dependencies: [
                "RenJistrolyConversation",
                "RenJistrolyModels",
                "RenJistrolyCapability",
                "RenJistrolyIntelligence",
                "RenJistrolySystemBridge",
            ],
            path: "Tests/RenJistrolyConversationTests"
        ),

        // MARK: - Comprehensive Module Tests (new)

        .testTarget(
            name: "RenJistrolyTests",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolyEnterprise",
                "RenJistrolyProductIdentity",
                "RenJistrolySystemBridge",
            ],
            path: "Tests/RenJistrolyTests"
        ),

        // MARK: - Security Red Team Tests
        .testTarget(
            name: "SecurityTests",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolySystemBridge",
                "RenJistrolyProductIdentity",
                "RenJistrolyEnterprise",
                "RenJistrolyCapability",
            ],
            path: "Tests/SecurityTests"
        ),

        // MARK: - Long Running & Stability Tests
        .testTarget(
            name: "LongRunningTests",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolySystemBridge",
                "RenJistrolyEnterprise",
                "RenJistrolyProductIdentity",
            ],
            path: "Tests/LongRunningTests"
        ),

        // MARK: - Performance Tests
        .testTarget(
            name: "PerformanceTests",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolySystemBridge",
                "RenJistrolyEnterprise",
            ],
            path: "Tests/PerformanceTests"
        ),

        // MARK: - Regression Tests (手动运行 — 标记为 .manual tag)
        .testTarget(
            name: "RegressionTests",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolyEnterprise",
                "RenJistrolyProductIdentity",
                "RenJistrolySystemBridge",
            ],
            path: "Tests/RegressionTests"
        ),

        // MARK: - Test Plans (手动运行 — XCTest 版本)
        .testTarget(
            name: "RenJistrolyTestPlans",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolyEnterprise",
                "RenJistrolyProductIdentity",
            ],
            path: "Tests/RenJistrolyTestPlans"
        ),

        // MARK: - Integration Tests (端到端)
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolySystemBridge",
                "RenJistrolyEnterprise",
                "RenJistrolyCapability",
            ],
            path: "Tests/IntegrationTests"
        ),

        // MARK: - UI, Mock & Human Interaction Tests
        .testTarget(
            name: "RenJistrolyUITests",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolySystemBridge",
                "RenJistrolyCapability",
                "RenJistrolyEnterprise",
            ],
            path: "Tests",
            exclude: [
                "RenJistrolyModelsTests",
                "RenJistrolySystemBridgeTests",
                "RenJistrolyIntelligenceTests",
                "RenJistrolyCapabilityTests",
                "RenJistrolyConversationTests",
                "RenJistrolyTests",
                "RenJistrolyTestPlans",
                "SecurityTests",
                "LongRunningTests",
                "PerformanceTests",
                "RegressionTests",
                "IntegrationTests",
                "FaultRecoveryTests",
            ],
            sources: [
                "Mocks/MockScreenCapture.swift",
                "Mocks/MockModeManager.swift",
                "Mocks/MockActionEngine.swift",
                "Mocks/MockScrollBridge.swift",
                "UITests/UITestPlan.swift",
                "UITests/ScrollToolTests.swift",
                "UITests/ClickAccuracyTests.swift",
                "UITests/ScreenReadingTests.swift",
                "UITests/WindowManagementTests.swift",
                "UITests/ButtonInteractionTests.swift",
                "HumanInteractionTests/ModeSwitchTests.swift",
                "HumanInteractionTests/ErrorRecoveryTests.swift",
                "HumanInteractionTests/TrustFlowTests.swift",
            ]
        ),

        // MARK: - Fault Recovery Tests
        .testTarget(
            name: "FaultRecoveryTests",
            dependencies: [
                "RenJistrolyModels",
                "RenJistrolySystemBridge",
                "RenJistrolyEnterprise",
            ],
            path: "Tests/FaultRecoveryTests"
        ),
    ]
)
