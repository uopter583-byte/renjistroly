# Test Target 检查清单

分析时间: 2026-06-19
分析文件: Package.swift

## 已注册的 testTarget

| # | testTarget | path | dependencies | 状态 |
|---|-----------|------|-------------|------|
| 1 | `RenJistrolyModelsTests` | `Tests/RenJistrolyModelsTests` | `RenJistrolyModels` | ✅ |
| 2 | `RenJistrolySystemBridgeTests` | `Tests/RenJistrolySystemBridgeTests` | `RenJistrolySystemBridge` | ✅ |
| 3 | `RenJistrolyIntelligenceTests` | `Tests/RenJistrolyIntelligenceTests` | `RenJistrolyIntelligence` | ✅ |
| 4 | `RenJistrolyCapabilityTests` | `Tests/RenJistrolyCapabilityTests` | `RenJistrolyCapability` | ✅ |
| 5 | `RenJistrolyConversationTests` | `Tests/RenJistrolyConversationTests` | `RenJistrolyConversation` | ✅ |
| 6 | `RenJistrolyTests` | `Tests/RenJistrolyTests` | 4 个依赖 (Models, Enterprise, ProductIdentity, SystemBridge) | ✅ |
| 7 | `SecurityTests` | `Tests/SecurityTests` | 5 个依赖 | ✅ |
| 8 | `LongRunningTests` | `Tests/LongRunningTests` | 4 个依赖 | ✅ |
| 9 | `PerformanceTests` | `Tests/PerformanceTests` | 4 个依赖 | ✅ |
| 10 | `RegressionTests` | `Tests/RegressionTests` | 4 个依赖 | ✅ |

## 目录存在但未注册的 testTarget

以下目录在 `Tests/` 下存在，但未在 Package.swift 中注册为 `testTarget`：

| 目录 | 文件数 | 建议操作 |
|------|-------|---------|
| `Tests/HumanInteractionTests/` | 2 个 .swift | ❌ 缺失 — 添加 testTarget |
| `Tests/Mocks/` | 3 个 .swift | ❌ 缺失 — 添加 testTarget |
| `Tests/RenJistrolyTestPlans/` | 3 个 .swift | ❌ 缺失 — 添加 testTarget |
| `Tests/UITests/` | 4 个 .swift | ❌ 缺失 — 添加 testTarget |

## 依赖完整性检查

| testTarget | 所需模块 | 依赖是否包含 | 建议 |
|-----------|---------|-------------|------|
| RenJistrolyModelsTests | RenJistrolyModels | ✅ 已包含 | — |
| RenJistrolySystemBridgeTests | RenJistrolySystemBridge | ✅ 已包含 | — |
| RenJistrolyIntelligenceTests | RenJistrolyIntelligence | ✅ 已包含 | — |
| RenJistrolyCapabilityTests | RenJistrolyCapability | ✅ 已包含 | — |
| RenJistrolyConversationTests | RenJistrolyConversation | ✅ 已包含 | — |
| RenJistrolyTests | Models, Enterprise, ProductIdentity, SystemBridge | ✅ 已包含 | — |
| SecurityTests (5 deps) | Models, SystemBridge, ProductIdentity, Enterprise, Capability | ✅ 已包含 | — |
| LongRunningTests (4 deps) | Models, SystemBridge, Enterprise, ProductIdentity | ✅ 已包含 | — |
| PerformanceTests (4 deps) | Models, SystemBridge, Enterprise, ProductIdentity | ✅ 已包含 | — |
| RegressionTests (4 deps) | Models, Enterprise, ProductIdentity, SystemBridge | ✅ 已包含 | — |

## 标记为 manual 的 testTarget

| testTarget | 标记 | 备注 |
|-----------|------|------|
| RegressionTests | `manual` | 需要手动环境，不自动运行 |

## 建议

1. **添加缺失的 testTarget** — 将 HumanInteractionTests、Mocks、RenJistrolyTestPlans、UITests 注册到 Package.swift
2. **Testing 框架迁移** — 执行 `Scripts/fix-test-imports.sh --apply` 自动转换后，仍需手动添加 XCTestCase 类包裹
3. **Swift 6.2 兼容性** — 确认所有 testTarget 使用 `.macOS(.v15)` 平台
