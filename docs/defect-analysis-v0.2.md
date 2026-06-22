# RenJistroly v0.2.0 缺陷分析与修复计划

> 基于知识图谱（1401 节点/1426 边）及代码静态分析生成
> 分析时间: 2026-06-21

---

## 一、架构概览

### 1.1 模块依赖拓扑（已验证无循环依赖）

```
Core 层:        RenJistrolyModels (1857 入边, 0 出边)
                RenJistrolySystemBridge (553 入边, 346 出边 → Peekaboo)

中间层:         RenJistrolyCapability (495 调用 → Models, 343 → SystemBridge)
                RenJistrolyIntelligence (210 → SystemBridge, 196 → Models)

入口层:         RenJistrolyConversation (386 入边)
                RenJistrolyUI
                RenJistrolyApp
```

### 1.2 规模指标

| 指标 | 值 |
|---|---|
| Swift 源文件 | 1,615 |
| 总行数 | ~73,179 |
| 测试文件 | 168 |
| 测试行数 | ~40,065 |
| 文档文件 (docs/) | 54 |
| 外部依赖 (Peekaboo) | 9,894 节点 (21.6%) |
| 模块数 | 16 |

### 1.3 架构亮点

- **单向依赖**：从 App → UI → Conversation → Intelligence/Capability → SystemBridge → Models，与 CLAUDE.md 一致
- **核心层纯净**：`RenJistrolyModels` 无内部依赖，纯数据定义 + 协议
- **入口层无入边**：Conversation 和 Intelligence 只有出向调用，不反向依赖 UI

---

## 二、严重缺陷（优先级 1）

### P1-1: ActionEngine.swift 重构残留

**文件**: `Sources/RenJistrolyEnterprise/ActionEngine.swift`（约 1000 行）
**标签**: `@unchecked Sendable`, `@MainActor`, 已记录但未修复

**问题**:
1. 该文件经历过 `actor → @MainActor` 的重构，但内部残留了旧代码的引用
2. `queue.sync` 引用了已移除的 `queue` 属性（若旧代码残留未清理干净将编译失败）
3. 某些构建环境下出现 `cannot assign through subscript: 'records' is a get-only property`
4. 某些环境出现 `cannot find '__records' in scope`（双下划线引用旧命名）
5. 当前标记 `@unchecked Sendable`，意味着并发写操作无任何编译器保护

**影响范围**:
- `ActionEngine` 是企业安全模式的核心组件，负责所有操作的风险评级和审批流
- 任何构建失败或运行时数据竞争都会导致整个企业安全模式不可用

**修复方案**:
1. 全局搜索该文件中 `records`、`__records`、`queue` 的所有引用，清理旧命名
2. 将 `_records` 写操作统一为 `_records[id]`，不经过计算属性
3. 评估是否改回 `actor`（提供真正的 actor 隔离），避免 `@unchecked Sendable`
4. 添加 `Sendable` 约束的单元测试覆盖并发写场景

**预估工时**: 2-4 小时

---

### P1-2: `@unchecked Sendable` 泛滥（18+ 处）

当前项目中大量使用 `@unchecked Sendable` 绕过 Swift 6 的发送检查。这本质上是把并发安全责任从编译器转移到了开发者身上。

| 文件 | 类/结构体 | 风险说明 |
|---|---|---|
| `NativeSpeechTranscriber.swift:11,63` | `SendableBufferRequest`, `NativeSpeechTranscriber` | 音频缓冲区传递，有数据竞争风险 |
| `OCRService.swift:93` | `OCRService` | 多线程 OCR 请求，Vision 框架回调 |
| `ChromeDevToolsSession.swift:30` | `ChromeDevToolsSession` | WebSocket + CDP 异步消息 |
| `ActionEngine.swift:121` | `ActionEngine` | 并发操作审计 |
| `ModeManager.swift:138` | `ModeManager` | 模式状态切换 |
| `ClaudeCodeCLI.swift:54,136,142` | `Buffer`, `LineBuffer`, `FinishGuard` | Process I/O 回调 |
| `CodexCLIBackend.swift:106,120,129` | `StreamFinisher`, `StderrCapture`, `LineBuffer` | 同上模式 |
| `HotkeyManager.swift:5` | `HotkeyManager` | 全局热键回调 |
| `TaskBag.swift:6` | `TaskBag` | 任务取消管理 |
| `ConversationEngine.swift:2567` | `TaskBag`（重复定义） | 同上 |
| `FocusGuard.swift:181` | `SuppressionDispatcher` | AX 通知分发 |
| `MacOSSpeechRecognizer.swift:9` | `MacOSSpeechRecognizer` | 系统语音识别 |

**修复优先级**:
1. 第一梯队（频繁调用路径）：`ChromeDevToolsSession`、`OCRService`、`ClaudeCodeCLI`
2. 第二梯队（核心业务）：`ActionEngine`、`ModeManager`、`HotkeyManager`
3. 第三梯队（工具类）：`TaskBag`（去重+actor）、`FocusGuard`

**通用修复模式**:
```swift
// 替换前
public final class Foo: @unchecked Sendable { ... }

// 替换后
actor Foo { ... }
// 或
public final class Foo: Sendable {
    private let lock = NSLock()  // 或 OSAllocatedUnfairLock
    ...
}
```

**预估工时**: 4-8 小时（18 处，每处 15-30 分钟 + 测试覆盖）

---

## 三、高复杂度模块（优先级 2）

### P2-1: 四个高复杂度方法

| 方法 | 文件:行 | 圈复杂度 | 认知复杂度 | 循环数 | 建议动作 |
|---|---|---|---|---|---|
| `ConversationEngine.sendMessage` | ConversationEngine.swift:? | **41** | **87** | 5 | 拆分为 3-5 个方法 |
| `ComputerUseRuntime.evaluateVerification` | ComputerUseRuntime.swift:? | **41** | **73** | 0 | 提取验证规则 |
| `AgentOrchestrator.execute` | AgentOrchestrator.swift:? | **32** | **85** | 7 | 拆分步骤执行器 |
| `CommandParser.parse` | CommandParser.swift:? | **31** | **31** | 0 | 用策略模式替代 switch |

**圈复杂度 > 30 意味着**：
- 该方法的路径数超过 2^30，人肉验证不可能
- 单元测试至少需要 41+ 个用例做到语句覆盖
- 认知复杂度 > 80 表明开发者需要同时跟踪 80+ 个分支状态

**修复方案**:
```swift
// AgentOrchestrator.execute 拆分为:
// - execute() → 编排步骤
// - executeStep(_:) → 单步执行
// - collectStepResults() → 结果聚合
// - handleStepError(_:) → 错误处理
```

**预估工时**: 6-12 小时（4 个方法，含测试重构）

---

### P2-2: 14 个怪兽文件（>1000 行）

| 排名 | 文件 | 行数 | 模块 | 建议拆分 |
|---|---|---|---|---|
| 1 | `BusinessScenarioTools.swift` | **3,390** | Capability | 按场景领域拆分 3-4 文件 |
| 2 | `ConversationEngine.swift` | **2,599** | Conversation | 拆出 MessageHandler、StreamManager |
| 3 | `AssistantSessionController.swift` | **2,318** | Intelligence | 拆出 SessionContext、PromptBuilder |
| 4 | `EngineerScenarioTools.swift` | **1,968** | Capability | 按工具类别（crash/git/profile）拆分 |
| 5 | `AppDrivers.swift` | **1,831** | SystemBridge | 按 app driver 拆分 |
| 6 | `AccessibilityContextProvider.swift` | **1,373** | SystemBridge | 拆出 ElementCollector、ContextFormatter |
| 7 | `ComputerUseRuntime.swift` | **1,277** | Capability | 拆出 VerificationEngine、ActionScheduler |
| 8 | `CommandParser.swift` | **1,267** | Intelligence | 拆出 CommandTokenizer、CommandMapper |
| 9 | `ProductManagerTools.swift` | **1,141** | Capability | 按产品工具拆分 |
| 10 | `BusinessScenarioModels.swift` | **1,132** | Models | 拆出 Scenario、ScenarioGroup |
| 11 | `TrustMechanisms.swift` | **1,040** | Models | 拆出信任机制子类型 |
| 12 | `DeveloperToolbox.swift` | **1,035** | Capability | 按工具拆分 |
| 13 | `DesignerTools.swift` | **1,032** | Capability | 按设计工具拆分 |
| 14 | `AccessibilityBridge.swift` | **1,005** | SystemBridge | 拆出 WindowManager、ElementQuery |

**为什么优先处理这个**：大型文件 = 低可维护性 = 高缺陷密度。这些 14 个文件占源文件总数的不到 1%，但贡献了约 35% 的代码行数。

**预估工时**: 16-24 小时（14 个文件，含回归测试）

---

## 四、中优先级（优先级 3）

### P3-1: 内聚度较低的模块/集群

图谱聚类分析显示 3 个 Sources 集群内聚度在 **0.66-0.80** 之间（低于 0.85 的阈值），说明这些集群可能混入了不应属于该模块的代码：

| 集群 | 标签 | 成员 | 内聚度 | 疑点 |
|---|---|---|---|---|
| Cluster 76 | Sources | 197 | **0.796** | 混合了 AccessibilityBridge、PermissionCenter、execute 等 |
| Cluster 62 | Sources | 387 | **0.713** | 混合了 ToolCallResult、String、resume 等 |
| Cluster 30 | Sources | 129 | **0.661** | 混合了 JSONDecoder、FinderDriver、Chrome 等 |

**建议**: 检查这些集群是否暗示了缺少的模块边界（比如 `SystemBridge` 可能应该继续细分为 `AXBridge`、`FileBridge`、`ChromeBridge`）

---

### P3-2: 未保护的递归

知识图谱标识了 4 个递归方法：

| 方法 | 复杂度 | 是否受保护 |
|---|---|---|
| `NativeSpeechTranscriber.start` | 6 | **否**（unguarded） |
| `AudioCapture.start` | 4 | **否**（unguarded） |

这两个方法可能在特定条件下导致栈溢出。

**修复方案**: 添加递归深度守卫（如最大 20 层），或在调用栈中传递 depth 参数。

---

### P3-3: 剩余问题

| 问题 | 位置 | 严重度 | 说明 |
|---|---|---|---|
| `try!` 暴力解包 | NemotronASRProvider.swift:35 | 中 | ONNX 指针操作失败直接 crash |
| 无测试覆盖的文件 | 多个位置 | 中 | 部分 Capability 工具文件无测试 |
| Peekaboo 耦合 | SystemBridge(198) + Capability(148) | 低 | 升级 Peekaboo 需要改两层 |
| `TaskBag` 重复定义 | TaskBag.swift + ConversationEngine.swift | 低 | 行为可能不一致 |

---

## 五、已知未修复问题（来自 docs/limitations.md）

以下问题已记录但当前版本中尚未修复：

| 问题 | 来源 | 状态 |
|---|---|---|
| ModeManager 静态成员引用错误 | limitations.md §1.1 | 未修 |
| ActionEngine 重构残留 | limitations.md §1.2 | 未修 |
| 场景 466-495 空白（30 个） | limitations.md §2.1 | 未实现 |
| 场景 556-575 空白（20 个） | limitations.md §2.1 | 未实现 |
| 场景 436-440 编号重叠 | limitations.md §2.2 | 设计歧义 |

---

## 六、修复路线图

### Sprint 1：关键修复（1-2 天）

```
目标：消除编译不稳定性和数据竞争风险
范围：
├── ActionEngine.swift 重构残留清理
│   ├── 搜索清理 queue、__records 旧引用
│   ├── 统一 _records 写路径
│   ├── 添加 Sendable 并发测试
│   └── 评估 actor 化
├── ModeManager.swift 静态成员修复
│   └── writeActions/mouseActions/networkActions/sensitiveActions → static let
└── TaskBag 去重
    ├── 统一到 TaskBag.swift
    └── 用真正 actor 替换 @unchecked Sendable
```

### Sprint 2：高复杂度重构（2-3 天）

```
目标：降低核心方法的认知负荷
范围：
├── ConversationEngine.sendMessage 拆分 (41→~10)
├── AgentOrchestrator.execute 拆分 (32→~8)
├── ComputerUseRuntime.evaluateVerification 拆分 (41→~15)
└── 对应的测试重构
```

### Sprint 3：@unchecked Sendable 治理（2 天）

```
目标：减少 50%+ 的 @unchecked Sendable
范围：
├── 第一梯队：ChromeDevToolsSession、OCRService、ClaudeCodeCLI
├── 验证：对替换后的类运行 TSAN（Thread Sanitizer）
└── 如果 TSAN 无警告，视为安全替换
```

### Sprint 4：怪兽文件拆分（3-5 天）

```
目标：消除 >2000 行的文件
范围：
├── BusinessScenarioTools.swift (3390行)→ 3-4 文件
├── ConversationEngine.swift (2599行)→ 3 文件
├── AssistantSessionController.swift (2318行)→ 3 文件
└── EngineerScenarioTools.swift (1968行)→ 2-3 文件
```

### Sprint 5：补充与收尾（2 天）

```
目标：填补剩下的缺口
范围：
├── 空白场景的基础数据模型定义
├── 场景编号冲突解决方案（436-440）
├── NativeSpeechTranscriber 递归保护
├── NemotronASRProvider try! 处理
└── 低内聚集群（Cluster 30/62/76）边界审计
```

---

## 七、总结

| 严重度 | 问题数 | 预估工时 |
|---|---|---|
| P1（关键） | 2 | 6-12h |
| P2（高） | 2 | 22-36h |
| P3（中） | 4 | 4-8h |
| 已知未修 | 5 | 部分含在 Sprint 1 |
| **总计** | **13** | **32-56h** |

**最值得优先投入的 3 件事**：
1. ActionEngine 重构残留（P1-1）— 企业安全模式核心，现在不可靠
2. `@unchecked Sendable` 第一梯队（P1-2）— 减少数据竞争面
3. `ConversationEngine.sendMessage` 拆分（P2-1）— 最核心的编排路径，风险最高
