# UI 验收测试方案

## 现状分析

当前测试覆盖（168 个测试文件，40,000 行）：

```
✅ 单元测试         — Models、SystemBridge、Intelligence 各模块
✅ 安全测试         — SecurityTests（数据外泄、注入）
✅ 性能基准测试     — PerformanceTests（响应时间、内存）
✅ 回归测试         — RegressionTests（跨模块、升级）
✅ 长稳测试         — LongRunningTests（压力、状态机）
❌ 端到端 UI 验收   — 缺失
```

现有 `UITests/` 和 `HumanInteractionTests/` 全部基于 **Mock 对象**，不启动真实 App。

## 三层方案

按投入产出比从高到低排列：

### 第一层：ViewModel 单元测试（推荐优先做）

**思路**：将 SwiftUI View 中的逻辑提取到 ViewModel / @Observable 类中，用纯 Swift 单元测试验证状态机。

**现状**：AppState、ConversationEngine 已使用 `@Observable`，可直接测试。

**示例覆盖**：

| View | 可测内容 | 现有状态 |
|------|----------|----------|
| FloatingPanelView | 状态文本、语音按钮可见性、模式切换 | 面板逻辑在 View 内 |
| MainWindowView | 侧边栏过滤、对话切换、Claude 启动器 | 嵌入在 body 中 |
| ModeControlPanel | 模式开关、策略锁定、风险标签 | 可测（有 ModeManager） |
| SettingsPanel | 提供者切换、语音配置、安全策略 | 部分可测 |

**工作量**：从 View 中提取 3-5 个 ViewModel，约 2-3 小时。测试编写约 1 小时。

### 第二层：ConversationEngine 集成测试（中等优先级）

**思路**：用真实的 ConversationEngine + Mock LLMBackend + Mock MCPToolRegistry，验证完整的对话循环。

**测试场景**：

1. 发送消息 → LLM 返回工具调用 → 工具执行 → 结果返回
2. 高风险操作 → 确认弹窗 → 用户批准/取消
3. 语音输入 → 转写 → 发送 → 回复 → TTS
4. 多轮对话上下文压缩

**现状**：已有 ConversationEngineTests（694 行），但集中在单元层面。需要新增 3-5 个端到端流程测试。

**工作量**：约 3-4 小时。

### 第三层：XCUITest 真实 UI 自动化（低优先级，难度大）

**思路**：使用 XCUITest 框架，真机拉起 RenJistroly.app，模拟用户点击操作。

**难点**：
- 需要完整授权（辅助功能、屏幕录制）
- 每个场景需要 App 在特定状态
- CI 环境难以跑通（需要显示器、权限）
- macOS 15+ 多窗口管理复杂

**可选场景**（手动运行，不进 CI）：

| 场景 | 操作 | 验证 |
|------|------|------|
| 面板显示 | Option+Space | 面板出现 |
| 文字发送 | 输入文本 → 回车 | 消息出现在列表 |
| 语音按钮 | 点击 🎤 | 状态变蓝色 |
| 模式切换 | 菜单 → 展开 | 窗口切换 |
| 退出确认 | 菜单 → 退出 | 确认弹窗 |

**工作量**：约 1-2 天搭建框架 + 每个场景 1-2 小时。

## 建议执行顺序

```
Week 1: ViewModel 单元测试 (第一层)
Week 2: ConversationEngine 集成测试 (第二层)
Week 3: XCUITest 关键场景 (第三层，可选)
```

## 预期收益

| 层次 | 发现缺陷类型 | 覆盖率增量 |
|------|-------------|-----------|
| ViewModel | 状态错误、显示逻辑缺陷 | ~15% |
| 集成测试 | 工具调用失败、流程中断 | ~20% |
| XCUITest | UI 布局、交互反馈 | ~10% |

**关键指标**：从当前 ~55% 的代码覆盖率提升到 ~75%，同时覆盖 10 个核心用户场景（登录、对话、工具执行、模式切换、语音输入、审计查看）。
