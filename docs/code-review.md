# Code Review: Enterprise Modules

> 评审日期：2026-06-19 · 范围：Sources/RenJistrolyEnterprise + RenJistrolyProductIdentity

## 模块评分

| 模块 | 依赖 | 内聚性 | 接口设计 | 错误处理 | 并发 | 测试性 | 平均 |
|------|------|--------|----------|----------|------|--------|------|
| ModeManager | 5 | 4 | 4 | 3 | 3 | 4 | 3.8 |
| ActionEngine | 5 | 5 | 4 | 3 | 3 | 4 | 4.0 |
| ContextProvider | 5 | 4 | 3 | 2 | 3 | 4 | 3.5 |
| PolicyLayer | 5 | 5 | 4 | 4 | 3 | 2 | 3.8 |
| 其余 ProductIdentity | 5 | 4 | 3 | 3 | 3 | 2 | 3.3 |

## 逐模块分析

**RenJistrolyEnterprise (4 文件)** — 职责清晰，分层明确。ActionEngine 从 create 到 rollback 的完整生命周期覆盖到位。ModeManager 通过 handler 注册实现了模式的可扩展性，弱依赖 Models，无循环依赖。ContextProvider/DevContextProvider 使用 protocol + optional provider 的注入模式，但 provider 缺失时静默返回空快照，无健康检测。

**RenJistrolyProductIdentity (13 文件)** — 每个文件单一职责，高内聚。PolicyLayer 的 Rule 闭包注册机制灵活可插拔。WindowMatchValidator 和 TestMatrixPlanner 为纯值类型，可测性最佳。但 7/13 的类型使用全局 singleton 模式，严重制约隔离测试。

## 5 个最重要的改进点

1. **Singleton 过载** — ProductIdentity 中 7 个类型（PolicyLayer / ReadOnlyModeEnforcer / MouseGuard / ScreenStabilityMonitor / AuditHighRiskAction / CancelMechanism / ContextAcquisitionManager）都是 `shared` 单例。单例之间无清晰初始化顺序，跨测试共享状态不可隔离。应改为实例化 + 依赖注入。

2. **`ActionRiskLevel` 重复定义** — RenJistrolyEnterprise/ActionEngine.swift 和 RenJistrolyModels 各自定义了 `ActionRiskLevel`。ProductIdentity 引用了 Models 版本，Enterprise 引用了本地版本。应统一收拢到 Models。

3. **`@unchecked Sendable` + DispatchQueue 模式** — ModeManager / ActionEngine / ContextManager / MouseGuard / ScreenStabilityMonitor 共 5 个类使用此模式。Swift 6.2 应优先使用 `actor`，编译期保证数据竞争安全。

4. **三个独立门禁系统不组合** — ModeManager（模式评估）、PolicyLayer（策略规则）、ReadOnlyModeEnforcer（只读强制）各自定义 `evaluate` 逻辑，调用方需自行决定顺序和优先级。无法通过配置组合。应统一为单链 PolicyEvaluator。

5. **存根实现未完成** — `ActionVerificationEngine.verify()`、`ContextAcquisitionManager.acquireContext()`、`ScreenStabilityMonitor.checkStability()` 均返回硬编码/空值，非生产可用状态。

## 架构改进建议

1. **门禁层统一** — 将 ModeManager、PolicyLayer、ReadOnlyModeEnforcer 合并为 `PolicyEvaluator`，接收 `[any PolicyRule]` 有序规则链。每条规则返回 `.allow` / `.deny(reason)` / `.confirm(message)`，优先匹配 `deny`。消除三套独立评估入口。

2. **`@unchecked` 类迁移到 actor** — 5 个 `@unchecked Sendable` 类改为 `actor`，利用 Swift 6.2 编译器隔离保证。`ActionEngine` 的 `onStatusChange` 回调需要适配 `@MainActor` actor 间的跨隔离域通信。

3. **ContextProvider 增加退化保障** — `ContextManager.provider` 从 `optional` 改为带默认 `FallbackContextProvider` 实例，避免空悬期返回空数据。同时增加 provider 心跳检测（例：每 30 秒检查 provider 是否响应）。
