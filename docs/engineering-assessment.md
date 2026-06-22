# RenJistroly 工程成熟度评估与路线图

> 评估日期：2026-06-19
> 评估范围：全模块（7 个 target、~148 个测试函数、21 个测试文件）

---

## 总览：整体完成度

| 维度 | 评分 | 说明 |
|------|------|------|
| 架构完成度 | 72-80% | 模块依赖清晰、协议定义完整、MCP 工具注册完备 |
| 真实可用能力 | 35-45% | 多数模块停留在"能调用"阶段，未到"能稳定完成真实任务" |
| Codex 级 agent 闭环 | 28-35% | observe-act-verify-recover 循环骨架在，但 verifier/recovery 覆盖不全 |
| 日常客户稳定使用 | 20-30% | 缺深度验证、恢复机制、长期记忆、统一事件流 |

**核心判断**：不是空框架，已经长出了内脏和骨架。但肌肉（执行可靠性）、神经反射（统一事件流）、协调能力（跨模块联动）还不够厚。

---

## 一、模块成熟度矩阵

### 1. Computer Use Runtime（observe → act → verify → recover）

| 项 | 状态 | 详情 |
|----|------|------|
| 主循环 | ✅ 完整 | `ComputerUseRuntime.swift`（953行），完整闭环 |
| Verifier | ⚠️ 偏浅 | 支持 focused element value、file existence、terminal exit code、app/window/title、field diff；**缺截图级 OCR diff** |
| Recovery | ⚠️ 偏策略列表 | 5 种 RecoveryStrategy（reobserveAndRetry / remapByStableID / coordinateClickFallback / activateTargetApp / reopenBrowserPage），但恢复选择是确定性的，未使用 WorkflowMemoryStore 的学习权重 |
| Target ID | ❌ 不够强 | 缺少稳定可跨操作的 element identifier |
| 超时控制 | ❌ 缺失 | 单步动作无超时 |
| 并发安全 | ❌ 未验证 | Tool execution 在 loop 内无并发保护 |

**成熟度**：55% — 闭环骨架完整，但验证深度和恢复智能度不够。

**验收标准**：
- [ ] 每个 GUI 动作后有截图级验证（OCR diff before/after）
- [ ] Recovery 策略权重从 WorkflowMemoryStore 动态学习
- [ ] 每步动作有独立超时（默认 15s，可配置）
- [ ] 并发 action 队列保护

---

### 2. Desktop Context Collector

| 项 | 状态 | 详情 |
|----|------|------|
| 基础采集 | ✅ 完整 | 10 个字段并行（active app、window title、focused element、selected text、browser/finder state、window list、AX tree depth=3） |
| 历史 diff | ❌ 缺失 | 纯快照，无 before/after 对比 |
| OCR 集成 | ❌ 未集成 | 采集器不触发 OCR，OCR 走独立路径 |
| 驱动层集成 | ⚠️ 硬编码 | Safari/Chrome/Finder 状态读取直接调用，非通过 driver registry |
| 缓存/去重 | ❌ 缺失 | 重复采集浪费资源 |

**成熟度**：45% — 覆盖面够广，但缺少差分和驱动抽象。

**验收标准**：
- [ ] 每次 collect 产出 `DesktopContextDelta`（与上次对比）
- [ ] OCR 文字作为可选字段集成进 context
- [ ] 通过 `AppDriverRegistry` 统一采集，不再硬编码
- [ ] 10s 内重复采集直接返回缓存

---

### 3. Workflow Memory Store

| 项 | 状态 | 详情 |
|----|------|------|
| 存储/检索 | ✅ 完整 | TF-IDF + tokenizer（支持 CJK），JSON 文件持久化 |
| 记忆类型 | ❌ 单一 | 只有 `TaskMemory`，无 episodic/semantic/procedural 分类 |
| 长期记忆 | ❌ 缺失 | 无记忆衰退、无过期、无优先级加权 |
| 用户偏好 | ❌ 缺失 | 不记录用户偏好或习惯 |
| 项目上下文 | ❌ 缺失 | 不知道当前项目是什么 |
| 跨会话连续性 | ⚠️ 基础 | 持久化到磁盘但无 schema migration |
| Recovery 学习 | ⚠️ 脆弱 | 依赖字符串前缀 tag（`strategy:`/`app:`/`tool:`）而非结构化字段 |

**成熟度**：30% — 能存能查，但不是真正的长期记忆系统。

**验收标准**：
- [ ] 支持 episodic / preference / project / failure-pattern 四类记忆
- [ ] 记忆衰退曲线（30 天未使用降权，90 天归档）
- [ ] Recovery 策略权重从结构化字段学习，不依赖 string tag
- [ ] Schema migration 机制

---

### 4. SmartRouter / TaskRouter

| 项 | 状态 | 详情 |
|----|------|------|
| Provider 路由 | ✅ 完整 | 复杂度评分（token count + step markers + domain + code depth + failure awareness），优先级排序 |
| 任务分类 | ⚠️ 关键词 | 中英文关键词 + URL 模式 + git 前缀，置信度 >=0.75 跳过 LLM |
| 任务分解 | ❌ 无 | `SmartRouter`/`TaskRouter` 只做单次路由，不做分解 |
| Fallback | ✅ 完整 | SmartRouter：优先级列表 + localMLX 兜底；TaskRouter：LLM 分类兜底 |
| 成本感知 | ❌ 缺失 | 不考虑 token 成本选择 provider |
| 动态路由 | ❌ 缺失 | 不能中途换 provider 继续任务 |
| 结果反馈 | ❌ 缺失 | 路由决策不根据结果自我修正 |

**成熟度**：50% — 路由机制完善，但策略偏浅，无自我改进。

**验收标准**：
- [ ] 路由加入 token 成本权重
- [ ] 支持"中途换路线"——provider A 失败后 provider B 接续上下文
- [ ] 路由决策成功率统计 + 自我调整权重

---

### 5. Claude Code Bridge

| 项 | 状态 | 详情 |
|----|------|------|
| 进程管理 | ✅ 完整 | `Process` 封装，`AsyncStream<String>` 和 `AsyncStream<ClaudeCodeEvent>` 双模式 |
| Stream 处理 | ✅ 完整 | readability handler + newline buffer + JSON-lines 解析 |
| 结构化解析 | ❌ 弱 | 构建/测试结果、文件变更、审批请求全用 regex/字符串匹配，无结构化 schema |
| Task 生命周期 | ✅ 完整 | queued → running → waitingForConfirmation → completed/failed/cancelled |
| 错误恢复 | ⚠️ 基础 | retry() 重置状态重跑，无增量恢复 |
| 审批流程 | ⚠️ 关键词 | 22 个硬编码关键词检测审批请求，非结构化 |
| 并行/多 agent | ❌ 缺失 | 无多 agent 协作、无任务分派、无工作隔离 |

**成熟度**：50% — 接入已完整，但还没成为开发工作流中枢。

**验收标准**：
- [ ] Claude Code 输出用结构化 schema 解析（非 regex）
- [ ] 支持 `--worktree` 隔离模式
- [ ] 审批检测从 22 个关键词升级为结构化 `permissionRequest` 事件
- [ ] 多 agent 并行 + 结果汇总

---

### 6. App Drivers

| Driver | 行数 | 操作数 | 验证 | 缺失重点 |
|--------|------|--------|------|---------|
| FinderDriver | 68 | 5 | ❌ | 无移动/重命名/删除/复制/新建/批量操作/冲突确认 |
| SafariDriver | 110 | 6 | ❌ | 有 DOM **读**（JS/CSS selector），无 DOM **写**（click/input/submit），无 tab 管理 |
| ChromeDriver | 37 | 3 | ❌ | 无 JS 执行、无 DOM、无 tab 管理。实际只是 URL 打开器 |
| TerminalDriver | 11 | 1 | ⚠️ exitCode | 无 PTY、无信号发送（Ctrl+C）、无持续输出、无多会话 |
| XcodeDriver | 74 | 5 | ⚠️ exitCode | 无文件导航、无行号跳转、无断点、无模拟器管理、scheme 推测脆弱 |
| SystemSettingsDriver | 32 | 3 | ❌ | 只能读不能写、28 个面板 11 个缺 URL 映射 |
| WeChatDriver | 99 | 5 | ⚠️ AppleScript exitCode | 只能发文本、无文件/图片、无群组、无未读、联系人歧义未消解 |

**共性问题**：
- 动作后验证几乎不存在（只有 WeChat 和 xcodebuild 检查结果）
- 无重试、无超时、无错误恢复逻辑
- MCP 工具直接实例化 driver 而不通过 registry
- `DesktopContextCollector` 按 app 名称嗅探选 driver

**成熟度**：Finder 40%、Safari 45%、Chrome 15%、Terminal 20%、Xcode 35%、SystemSettings 25%、WeChat 35%

**验收标准（以最高优先级为例）**：
- [ ] Safari/Chrome 支持 DOM 写入（click/fill/submit）
- [ ] Finder 支持移动/重命名/删除 + 操作前确认
- [ ] Terminal 支持 Ctrl+C 信号和持续输出流
- [ ] Xcode 支持文件跳转和行号导航
- [ ] 所有 driver 统一通过 registry 调用，有动作后验证

---

### 7. UI / Operator Console

| 项 | 状态 | 详情 |
|----|------|------|
| AgentConsoleView | ⚠️ 诊断面板 | 9 个信息段（TaskRouter、Multi-Agent Board、Developer Agent、Safety Audit、Timeline、Memory、Recovery、Skills、ComputerUse Trace），但**只读** |
| 审批交互 | ⚠️ 仅 Claude Code | `onApproveDeveloperTask` 只对 DeveloperAgentTask 有效，通用 tool 审批用 `AppState.pendingConfirmation` 但在 AgentConsole 不可见 |
| TraceConsolePanel | ⚠️ 延迟测量 | 显示 ASR/context/routing/TTFT/tool/TTS 各段延迟，不是操作台 |
| 时间线可操作性 | ❌ 缺失 | 可查看但不可操作（不能 rerun、不能 resume、不能 fork） |
| 任务总览 | ❌ 缺失 | 无统一 dashboard 展示进行中/等待/失败/已完成任务 |

**成熟度**：35% — 能看，不能指挥。

**验收标准**：
- [ ] 通用 tool 审批在 AgentConsole 可见可操作（批准/拒绝/修改参数）
- [ ] 失败步骤可一键 retry / skip / 手动修正
- [ ] 时间线支持 drill-down 查看失败原因
- [ ] 任务总览 dashboard（进行中/等待审批/失败/已完成）

---

### 8. 事件模型

| 项 | 状态 | 详情 |
|----|------|------|
| 独立事件流 | ✅ 多套并存 | `RealtimeEvent`(8 cases)、`AgentLoopEvent`(phase/tool/warning)、`TraceEvent`(11 kinds)、`TranscriptEvent`/`TurnEvent`、`DeveloperAgentEvent` |
| 统一事件流 | ❌ 缺失 | 5 套独立事件系统，没有统一的 agent event bus |
| 跨模块联动 | ❌ 缺失 | voice 有自己 FSM（`voiceState`），agent loop 有 `AgentLoopEvent`，trace 有 `TraceEvent`——互不联通 |

**成熟度**：25% — 各子系统有自己的事件，但不成体系。

**验收标准**：
- [ ] 定义统一的 `AgentEvent` enum，覆盖 voice/desktop/browser/code 所有事件
- [ ] 单一 `AsyncStream<AgentEvent>` 作为 session 级事件总线
- [ ] UI console 订阅事件总线统一渲染

---

### 9. 安全确认

| 项 | 状态 | 详情 |
|----|------|------|
| 风险分级 | ✅ 完整 | 3 级（low/medium/high）+ 16 种 `ToolActionCategory` |
| 自动执行策略 | ✅ 完整 | `ToolExecutionPolicy` 可配 autoApproveLow/Medium/High |
| 危险命令检测 | ✅ 已强化 | `ShellExecutor.hasUnsafePatterns` + `isMutatingShellCommand` 双重检测 |
| 用户解释层 | ❌ 缺失 | 不解释"为什么危险"——只显示操作描述 |
| 批量确认 | ❌ 缺失 | 连续同类危险操作每次都弹确认，无批量策略 |
| 端到端测试 | ❌ 缺失 | 安全逻辑无专项测试 |

**成熟度**：55% — 框架完整，但 UX 和测试不够。

**验收标准**：
- [ ] 危险操作确认时展示 risk reasoning（"此操作将删除 3 个文件"）
- [ ] 同 session 内同类操作可"批准并记住"（批量免确认）
- [ ] SafetyAuditStore 写入持久化审计日志
- [ ] 安全逻辑有至少 20 个专项端到端测试

---

### 10. 测试体系

| 模块 | 测试文件 | 测试函数 | 覆盖度评估 |
|------|---------|---------|-----------|
| RenJistrolyModels | 8 | 44 | 高 — 数据模型覆盖充分 |
| RenJistrolySystemBridge | 5 | 35 | 中 — Shell/accessibility 有测，但 OCR/截屏无测 |
| RenJistrolyCapability | 4 | 33 | 中 — 安全审计有测，但 MCP server 无测 |
| RenJistrolyConversation | 2 | 27 | 低 — 只覆盖了 Plan/Session 部分 |
| RenJistrolyIntelligence | 2 | 9 | 低 — Provider/路由几乎无测 |
| RenJistrolyUI | 0 | 0 | ⚠️ 零测试 |
| RenJistrolyApp | 0 | 0 | ⚠️ 零测试 |
| RenJistrolyMCP | 0 | 0 | ⚠️ 零测试 |
| RenJistrolyBridge | 0 | 0 | ⚠️ 零测试 |

**成熟度**：30% — 数据模型测得好，其余模块大面积空白。

**验收标准**：
- [ ] UI 层至少 20 个 snapshot/behavior 测试
- [ ] MCP server 所有 tool 有集成测试
- [ ] ComputerUseRuntime 有完整 mock-based 单元测试
- [ ] Safety 逻辑有专项测试套件

---

## 二、缺陷清单（按优先级）

### P0：挡住成品化的核心缺陷

| # | 缺陷 | 影响模块 | 验收标准 |
|---|------|---------|---------|
| P0-1 | Browser driver 无 DOM 写入和 DevTools 级能力 | SafariDriver / ChromeDriver | Safari/Chrome 支持 click/fill/submit + console/network 读取 |
| P0-2 | Computer Use verifier 覆盖不全 | ComputerUseRuntime | 每个 GUI 动作有截图级验证（OCR diff） |
| P0-3 | observe→act→verify→recover 未统一标准 | ComputerUseRuntime | 所有动作经过统一四阶段 pipeline，失败率可度量 |
| P0-4 | Claude Code 未成为开发工作流中枢 | ClaudeCodeBridge | 结构化输出解析 + build→test→fix→retest 闭环 |
| P0-5 | 无统一事件模型 | 全模块 | 单一 `AgentEvent` stream 覆盖 voice/desktop/browser/code |
| P0-6 | Recovery 策略不能从记忆学习 | WorkflowMemoryStore / ComputerUseRuntime | Recovery 权重从结构化记忆数据动态学习 |

### P1：高频客户会撞到的

| # | 缺陷 | 影响模块 | 验收标准 |
|---|------|---------|---------|
| P1-1 | 语音与桌面控制未深度融合 | AssistantSessionController | 说话时桌面状态实时注入 LLM 上下文 |
| P1-2 | Finder 文件操作无确认流 | FinderDriver | 移动/删除/覆盖前弹出确认，操作后验证结果 |
| P1-3 | WeChat 联系人歧义 + 发送前确认 | WeChatDriver | 多匹配时列出候选 + 发送前展示预览 |
| P1-4 | Terminal 并行任务无法分组和摘要 | TerminalDriver | 支持 task group + 失败摘要 |
| P1-5 | Xcode build/test/error navigation 不完整 | XcodeDriver | 支持文件跳转 + 行号导航 + 错误定位 |
| P1-6 | Provider fallback 对用户不可见 | SmartRouter | UI 展示当前 provider 和 fallback 链路 |
| P1-7 | 危险动作确认 UX 不成熟 | ToolSafetyGateway / UI | 展示 risk reasoning + "记住选择"批量免确认 |
| P1-8 | 失败时间线不可操作 | AgentConsoleView | 支持 retry/skip/modify/resume |
| P1-9 | 多模型结果不可对比 | SmartRouter | UI 支持并列展示多个模型回答 |
| P1-10 | 对话/任务/执行状态未统一 | AppState | 统一 session lifecycle FSM |

### P2：增强专业度和日常手感

| # | 缺陷 | 影响模块 | 验收标准 |
|---|------|---------|---------|
| P2-1 | 用户偏好不学习 | WorkflowMemoryStore | 记住用户常用 app/command/workflow |
| P2-2 | 项目上下文不记忆 | WorkflowMemoryStore | 自动关联当前 repo 的历史操作 |
| P2-3 | 无工作流模板 | WorkflowMemoryStore | "新建 PR"等常用流程一键触发 |
| P2-4 | 无自动回归测试生成 | 测试体系 | 修 bug 后自动生成对应 test case |
| P2-5 | 无修复原因自动总结 | ClaudeCodeBridge | 每次修复输出结构化 cause→fix→verification |
| P2-6 | 无错误模式自动分类 | WorkflowMemoryStore | 相似错误归类，建议修复策略 |
| P2-7 | 长任务不分解段播报 | AssistantSessionController | >30s 任务分阶段播报进度 |
| P2-8 | 权限诊断不够强 | AppDelegate | 启动时诊断全部 5 项权限并给出修复步骤 |
| P2-9 | CI/GitHub/PR 流程不深 | ClaudeCodeBridge | PR 创建→review→修改→merge 完整流程 |
| P2-10 | 任务记录不可回放 | AgentConsoleView | 历史任务可查看完整时间线回放 |

---

## 三、实施路线图

### Phase 1：打地基（先让现有能力"真能用"）

**目标**：把现有模块从"能调用"升级到"能稳定完成单步任务"

| 序号 | 任务 | 涉及模块 | 预估 |
|------|------|---------|------|
| 1.1 | 统一 AgentEvent 事件模型 | 全模块 | 定义 + 实现 ~2 天 |
| 1.2 | Computer Use verifier 补齐截图验证 | ComputerUseRuntime + ScreenContextProvider | 实现 ~1.5 天 |
| 1.3 | 所有 AppDriver 加动作后验证 | 7 个 driver | 实现 ~2 天 |
| 1.4 | MCP/Bridge 层专项测试 | RenJistrolyMCP / RenJistrolyBridge | 测试 ~1.5 天 |
| 1.5 | Operator Console 支持 retry/approve | AgentConsoleView | 实现 ~1.5 天 |

### Phase 2：长肌肉（多步联动和恢复能力）

**目标**：跨 app 的多步任务能自动完成并自我恢复

| 序号 | 任务 | 涉及模块 | 预估 |
|------|------|---------|------|
| 2.1 | Recovery 策略学习框架 | WorkflowMemoryStore + ComputerUseRuntime | ~2 天 |
| 2.2 | 浏览器 DOM 写入（click/fill/submit） | SafariDriver / ChromeDriver | ~2 天 |
| 2.3 | Finder 完整文件操作流 | FinderDriver | ~1.5 天 |
| 2.4 | Xcode 文件导航和错误定位 | XcodeDriver | ~1.5 天 |
| 2.5 | Claude Code 结构化输出解析 | ClaudeCodeBridge | ~1.5 天 |
| 2.6 | 统一 session lifecycle FSM | AppState + AssistantSessionController | ~1 天 |

### Phase 3：成品化（记忆、偏好、连续性）

**目标**：用户拿来日常用不心累

| 序号 | 任务 | 涉及模块 | 预估 |
|------|------|---------|------|
| 3.1 | 四类记忆系统（episodic/preference/project/failure） | WorkflowMemoryStore | ~2.5 天 |
| 3.2 | 用户偏好学习 | WorkflowMemoryStore + SmartRouter | ~1.5 天 |
| 3.3 | 工作流模板系统 | WorkflowMemoryStore + AgentConsoleView | ~1.5 天 |
| 3.4 | 安全确认 UX 升级 | ToolSafetyGateway + UI | ~1 天 |
| 3.5 | 任务记录回放 | AgentConsoleView + TraceEvent | ~1.5 天 |
| 3.6 | UI 层 snapshot/behavior 测试 | RenJistrolyUI | ~1.5 天 |

---

## 四、附录：测试矩阵建议

按用户框架，8 个矩阵的形成方式：

| 矩阵 | 覆盖目标 | 用例基数 | 建议测试文件 |
|------|---------|---------|-------------|
| 1. 开发任务 | 读代码→改代码→构建→测试→修失败→总结 | 200+ | `DevelopmentWorkflowTests.swift` |
| 2. 桌面操作 | 打开 app→切换窗口→点击→输入→快捷键→验证 | 300+ | `DesktopOperationTests.swift` |
| 3. 浏览器任务 | 打开页面→搜索→DOM→console→表单→登录态 | 200+ | `BrowserTaskTests.swift` |
| 4. 文件系统 | 搜索→打开→新建→重命名→移动→删除→恢复 | 150+ | `FileSystemTaskTests.swift` |
| 5. 多模型协作 | Claude Code/Codex/OpenClaw/Hermes/本地/fallback | 100+ | `MultiModelCoordinationTests.swift` |
| 6. 安全确认 | 高风险/隐私/批量/外发/删除/shell 写 | 80+ | `SafetyConfirmationTests.swift` |
| 7. 记忆连续性 | 偏好/项目上下文/失败模式/工作流/跨会话 | 100+ | `MemoryContinuityTests.swift` |
| 8. Operator Console | 时间线/原因/批准/重试/恢复/summarize | 80+ | `OperatorConsoleTests.swift` |

**建议测试总量**：~1200 个场景级测试 + 现有 148 个单元测试 = ~1350 个测试

---

*此文档将作为后续开发的基准参照。每个 Phase 完成后更新状态。*
