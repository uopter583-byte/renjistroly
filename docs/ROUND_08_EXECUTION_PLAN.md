# 第 8 轮：执行计划机制

**完成时间**：2026-06-14

## 完成了什么

用户一句话 → 生成多步骤计划 → 展示审批 → 逐步执行 → 汇总反馈。

### 新增文件
- `Sources/RenJistrolyModels/ExecutionPlan.swift` — `ExecutionPlan`（多步骤计划，状态机，进度跟踪）、`PlanStep`（描述+工具调用+风险等级+状态+结果）
- `Sources/RenJistrolyIntelligence/AgentOrchestrator/PlanGenerator.swift` — 复杂度判断（`shouldPlan`）+ LLM 计划生成（专用 prompt → 解析编号列表 → ExecutionPlan）
- `Sources/RenJistrolyUI/Components/PlanCard.swift` — 共享计划卡片组件，含状态图标、步骤进度、审批/取消按钮
- `Tests/RenJistrolyModelsTests/ExecutionPlanTests.swift` — 9 个测试（创建、进度、状态转换、风险聚合、边界）

### 修改文件
- `AppState` 新增 `activePlan`
- `ConversationEngine` 新增 `planGenerator`、计划生成路径（`shouldPlan` → `generatePlan` → `set activePlan`）、`approvePlan()`、`cancelPlan()`、`executePlan()`（逐步执行+每步走 R7 安全层确认）
- `FloatingPanelView` / `MainWindowView` 会话列表顶部显示 PlanCard

### 计划执行流程
1. 用户输入 → `PlanGenerator.shouldPlan()` 判断复杂度（长度/关键词/多意图）
2. 需要计划 → LLM 专用 prompt 生成 2-5 步骤列表 → 解析为 `ExecutionPlan`
3. 计划展示在 PlanCard → 步骤编号 + 待执行图标 + 批准/取消按钮
4. 用户批准 → `executePlan()` 逐步执行：
   - 每步发送给 `AgentOrchestrator`（带工具访问）
   - 工具调用走 R7 安全层（高风险暂停确认）
   - 每步结果实时更新到 PlanCard（pending → executing → ✓/✗）
5. 全部完成后汇总结果

## 代码状态
- 构建: `swift build` ✅
- 测试: 33 tests, 0 failures ✅
- 打包: `bash Scripts/package_app.sh` ✅

## 下一轮
**R9 — 开发者模式**：读项目、跑测试、分析报错、调用 Claude Code、生成修改建议。这是最高频使用场景。
