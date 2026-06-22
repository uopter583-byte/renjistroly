# 测试仪表盘

> 最后更新: 2026-06-19
> 构建状态: 因编译错误阻塞（并发修改导致）

## 当前测试统计

| 指标 | 数值 |
|------|------|
| 测试 Target 数 | 17 |
| 测试文件数 | 167 |
| 测试方法总数 (声明) | 3,219 |
| 测试通过率 | 无法运行（编译错误） |
| 覆盖率 | 无法生成（编译错误） |

## 各模块测试数量

| 模块 | 测试文件 | 测试方法 | 构建状态 |
|------|----------|----------|----------|
| RenJistrolyModelsTests | 39 | 499 | 通过 |
| RenJistrolySystemBridgeTests | 21 | 388 | 阻塞（FocusGuard / SpeechRecognizer） |
| RenJistrolyIntelligenceTests | 25 | 531 | 阻塞 |
| RenJistrolyCapabilityTests | 21 | 442 | 阻塞 |
| RenJistrolyConversationTests | 14 | 417 | 阻塞 |
| RenJistrolyTests | 7 | 445 | 阻塞 |
| SecurityTests | 5 | 106 | 阻塞 |
| PerformanceTests | 6 | 43 | 阻塞 |
| LongRunningTests | 2 | 32 | 阻塞 |
| RegressionTests | 6 | 116 | 阻塞 |
| RenJistrolyTestPlans | 3 | 40 | 阻塞 |
| IntegrationTests | 2 | 6 | 阻塞 |
| FaultRecoveryTests | 5 | 26 | 阻塞 |
| RenJistrolyUITests (含 HumanInteraction + UI) | 10 | 128 | 阻塞 |
| **合计** | **167** | **3,219** | — |

## 已知编译错误（阻塞测试运行）

| 文件 | 模块 | 问题 |
|------|------|------|
| `FocusGuard.swift` | RenJistrolySystemBridge | `OSAllocatedUnfairLock` 重构未完成，`token` 变量作用域错误 |
| `MacOSSpeechRecognizer.swift` | RenJistrolySystemBridge | Main actor 隔离违反（Sendable closure 中修改 @MainActor 属性）|
| `CiTestPlan.swift` | RenJistrolyTestPlans | Main actor-isolated `ModeManager.current` 在 nonisolated 上下文引用 |
| `FoundationModelsTests.swift` | RenJistrolyModelsTests | `testFoundationHealthStatusLabels()` 重复声明 |
| `StabilityMetricsTests.swift` | RenJistrolyModelsTests | `SessionManager` 无法找到；`testFoundationHealthStatusLabels()` 重复 |

## 覆盖率报告工具

`Scripts/coverage.sh` 已配置完成，修复了 macOS BSD find 兼容性，并支持自定义 `SCRATCH_PATH` 环境变量。修复编译错误后执行：

```bash
./Scripts/coverage.sh
```

生成：
- `docs/coverage-report.txt` — 文本覆盖率报告（按模块）
- `docs/coverage-html/index.html` — HTML 覆盖率报告

## 测试运行时间分布

| 阶段 | 耗时 |
|------|------|
| 单元测试 (Models) | 待运行 |
| 单元测试 (SystemBridge) | 待运行 |
| 单元测试 (Capability) | 待运行 |
| 单元测试 (Intelligence) | 待运行 |
| 单元测试 (Conversation) | 待运行 |
| 综合测试 (RenJistrolyTests) | 待运行 |
| 安全测试 | 待运行 |
| 性能测试 | 待运行 |
| **合计** | **待运行** |

> 更新方式: 先修复编译错误，然后运行 `./Scripts/coverage.sh` 并确认 exit code 0
