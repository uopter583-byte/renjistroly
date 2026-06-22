# Agent 能力边界与已知限制

RenJistroly Agent 的能力边界和当前已知限制。每个限制项附带解决方案或 workaround。

---

## 1. 编译与构建

### 1.1 ModeManager.swift 静态成员引用错误

**文件**: `Sources/RenJistrolyEnterprise/ModeManager.swift`

`registerDefaultHandlers()` 方法（第 221 行）通过 `Self.writeActions`、`Self.mouseActions` 等访问静态成员，但 `writeActions`、`mouseActions`、`networkActions`、`sensitiveActions` 被定义为文件级 `private let` 常量（第 239-242 行），位于类结束括号 `}` 之后。

```
// 报错: type 'Self' has no member 'writeActions'
// 原因: writeActions 是文件级常量而非 static let 类成员
```

**解决方案**: 将这四个常量改为 `static let` 放在 `ModeManager` 类内部：

```swift
private static let writeActions: Set<String> = [...]
private static let mouseActions: Set<String> = [...]
private static let networkActions: Set<String> = [...]
private static let sensitiveActions: Set<String> = [...]
```

### 1.2 ActionEngine.swift 构建不稳定

**文件**: `Sources/RenJistrolyEnterprise/ActionEngine.swift`

`ActionEngine` 类标记为 `@MainActor`（第 114 行），使用 `_records` / `_history`（`private var`）配合 `records` / `history` 计算属性。该模块在不同构建环境下曾报告以下不一致问题：

- `queue.sync` 引用了一个不存在/已移除的 `queue` 属性（若和旧代码残留冲突）
- 某些构建环境下出现 `cannot assign through subscript: 'records' is a get-only property`
- 某些环境出现 `cannot find '__records' in scope`（双下划线，引用到了旧的命名）

**根因**: 该文件经历过多次重构（从 actor → @MainActor，从 queue 保护 → 计算属性），残留代码未清理干净。

**解决方案**:
1. 检查是否存在旧变量名引用（搜索 `records`、`__records`、`queue`）
2. 确认 `_records` 写操作全部通过 `_records[id]` 而非 `records[id]`
3. 考虑完全移除 `@MainActor` 改为 actor 提供真正的 actor 隔离
4. 统一所有内部写操作对 `_records` 的引用

### 1.3 SwiftPM 构建锁冲突

RenJistroly 使用 SwiftPM 构建系统，在多进程并发构建时频繁出现：

```
Another instance of SwiftPM (PID: XXXX) is already running...
```

PM 进程不会自动清理残留锁，需要手动 `kill`。

**解决方案**: 在构建前增加 `pkill -f "swift-build"` 清理步骤，或使用 `Scripts/compile_and_run.sh`。

---

## 2. 场景覆盖率

### 2.1 场景 466-495 和 556-575 为完全空白

在 200 个编号场景（376-575）中，有 50 个场景（25%）在代码库中无任何定义、数据模型或实现：

- **466-495**（30 个场景）：无任何 MARK 注释、struct 或工具
- **556-575**（20 个场景）：无任何 MARK 注释、struct 或工具

这 50 个场景是编号体系中的预留槽位，目前完全没有实现。

### 2.2 场景 436-440 编号重叠

场景 436-440 在代码中被两个不同模块重复使用：

- `BusinessScenarioTools.swift` 将其定义为**开发者扩展工具**（代码评审、Git 工作流、终端、浏览器、项目诊断）
- `RoleScenarioGuards.swift` 将其定义为**财务守卫**数据模型（OCR 数字校验、金额验证等）

两套实现共享编号但关注不同能力维度。目前没有冲突，但可能造成需求追踪中的歧义。

### 2.3 执行层场景（496-555）缺乏独立工具

`ExecutiveUXModels.swift`（496-505）和 `TrustMechanisms.swift`（506-515）定义了 20 个数据模型，但没有对应的 `MCPTool` 实现。这些模型由 `ConversationEngine`、`AgentOrchestrator` 等上层模块使用，但无法通过 MCP 接口直接调用。

Operation Mode（516-525）、Action Engine（526-535）、System Context（536-545）、Dev Context（546-555）有完整的运行时代理实现（`ModeManager`、`ActionEngine`、`ContextManager`、`DevContextManager`），但与 MCP 工具层无桥接——无法通过 MCP 接口直接查询或操作这些状态。

---

## 3. 跨模块引用问题

### 3.1 RenJistrolyEnterprise 重复定义模型类型

`ActionEngine.swift` 在 `RenJistrolyEnterprise` 模块中独立定义了 `ActionRiskLevel`、`ActionRecord`、`AuditEntry` 等类型。这些类型与 `RenJistrolyModels` 中的模式不一致——其他模块（顶层应用、UI）可能需要访问或序列化这些类型，但由于它们在 Enterprise 模块中，被依赖于 Models 的模块引入时需要额外依赖。

**解决方案**: 将这些共享类型迁移到 `RenJistrolyModels`。

### 3.2 MCPTool 协议与 Models 分离

`MCPTool` 协议定义在 `RenJistrolyCapability/MCPServer/MCPToolRegistry.swift` 中，而 `ToolDefinition` 定义在 `RenJistrolyModels/Protocols.swift` 中。Enterprise 和 Models 模块无法定义自己的 MCPTool 实现，因为 MCPTool 协议在 Capability 模块中。Enterprise 场景（496-555）没有独立工具的根本限制就在于此。

**解决方案**:
- 将 `MCPTool` 协议迁移到 `RenJistrolyModels`，使 Enterprise 模块能实现自己的工具
- 或者 RenJistrolyEnterprise 添加对 RenJistrolyCapability 的依赖

---

## 4. 测试覆盖

### 4.1 场景工具无单元测试

55 个 MCPTool 实现在 `EngineerScenarioTools.swift`、`DesignerTools.swift`、`ProductManagerTools.swift`、`BusinessScenarioTools.swift` 中，但没有任何专门的单元测试。`RenJistrolyCapabilityTests` 目录存在但没有覆盖这些工具文件。

**解决方案**: 使用 `swift test --filter` 按模块运行测试，并为每个工具编写至少一个基本执行测试。

### 4.2 COrt（ONNX Runtime）C 绑定无测试覆盖

`Sources/COrt/COrt.c` 是 PP-OCRv6 依赖的 ONNX Runtime C 桥接，有 21 个 `warn_unused_result` 警告。所有 API 调用的返回值均未检查，错误未传播到 Swift 层。在生产环境中 ONNX 推理失败时，PP-OCRv6 会静默降级或返回空结果。

**解决方案**: 添加 C 层的错误检查和日志，确保 ONNX 运行时错误能传播到 Swift OCRService。

---

## 5. 能力边界

### 5.1 Figma 集成依赖 Web 端

`FigmaInspectTool`（场景 386）通过 OCR 截图检测 Figma 设计稿，依赖浏览器在前台运行。不支持 Figma Desktop 应用的原生 API 访问，也无法直接读取 Figma 的图层树、组件属性和样式数据。

**解决方案**: 如果 Figma 提供 REST API，可添加 `FigmaAPIClient` 桥接直接读取设计文件。

### 5.2 Beta 状态

- 语音输入（`VoiceSessionManager`、`MacOSSpeechRecognizer`、`NativeSpeechTranscriber`）仅通过本地代理与 Anthropic API 通信，未实现完整的端到端语音会话
- `PPOCRv6Service` 依赖本地 ONNX 模型文件，需要首次运行时下载
- 屏幕录制（`ScreenCaptureBridge`）在 macOS 15+ 上需要用户授予权限，权限回收后无法自动重提交

### 5.3 本地代理依赖

所有 Anthropic/OpenAI API 调用都通过本地代理中转。如果代理未运行或配置错误，LLM 调用会失败。

**解决方案**: 提供代理状态检查和自动启动脚本。
