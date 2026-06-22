# 第 7 轮：工具安全层

**完成时间**：2026-06-14

## 完成了什么

给 20 个内置工具建立了风险分级 + 自动/确认执行机制。

### 新增文件
- `Sources/RenJistrolyModels/ToolSafety.swift` — `ToolRiskLevel`（low/medium/high）、`ToolExecutionPolicy`（三种预设）、`ToolRiskAssessment`、`ToolNeedsConfirmationError`、`ToolRejectedError`、`ToolExecutionRecord`
- `Sources/RenJistrolyCapability/MCPServer/ToolSafetyGateway.swift` — 安全网关，包裹注册表做风险评估和策略检查
- `Tests/RenJistrolyModelsTests/ToolSafetyTests.swift` — 9 个测试（排序、策略、评估、记录）

### 修改文件
- `MCPTool` 协议新增 `riskLevel` 属性
- 20 个工具全部标注风险等级：
  - **Low（9个）**: system_info, running_apps, read_focused_text, list_windows, get_ui_tree, git_status, git_log, read_file, list_files
  - **Medium（6个）**: open_app, click_element, activate_menu, scroll, focus_window, press_key
  - **High（5个）**: type_text, drag, write_file, shell_command, claude_agent
- `AppState` 新增 `toolExecutionPolicy`、`pendingConfirmation`、`toolAuditLog`
- `MCPClient` 接入 `ToolSafetyGateway`
- `ConversationEngine` 在 toolExecutor 中加风险检查，低风险自动执行，中高风险抛 `ToolNeedsConfirmationError` → 暂停并等待用户确认
- `FloatingPanelView` / `MainWindowView` 加入确认弹窗（显示工具名、风险等级、操作摘要、批准/取消按钮）
- `SettingsView` 新增「安全」标签页，含三级自动执行开关 + 三种预设（默认/宽松/严格）

### 确认流机制
1. LLM 决定调用工具 → AgentOrchestrator 执行 toolExecutor
2. toolExecutor 检查风险：`policy.canAutoExecute(level)` → 通过直接执行
3. 不通过 → 抛 `ToolNeedsConfirmationError`
4. ConversationEngine 捕获 → `requestConfirmation()` 创建 CheckedContinuation → 设置 `pendingConfirmation`
5. UI 检测到 `pendingConfirmation` → 显示确认弹窗
6. 用户点批准/取消 → `resolveConfirmation(approved:)` 恢复 continuation
7. 批准则直接执行工具并返回结果

## 代码状态
- 构建: `swift build` ✅
- 测试: 24 tests, 0 failures ✅
- 打包: `bash Scripts/package_app.sh` ✅ 生成 RenJistroly.app

## 下一轮
**R8 — 执行计划机制**：用户一句话进来 → 先生成计划 → 再执行 → 再反馈结果。依赖 R7 的工具安全层（计划中的工具调用也能走风险检查）。
