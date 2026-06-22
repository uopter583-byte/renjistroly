# 深度测试计划 v2

> 测试架构师分析日期：2026-06-19
> 目标组件：ModeManager、ActionEngine、ContextProvider、ContextManager、DevContextManager
> 基于现有测试覆盖 v1 (EnterpriseModeTests, EnterpriseActionTests, EnterpriseContextTests, PerformanceTests, LongRunningTests/StateMachineStressTests, HumanInteractionTests/ModeSwitchTests) 的缺口

---

## 1. 并发竞争测试

### 设计思路

ModeManager 和 ActionEngine 均注解为 `@MainActor`，但 `ModeManager.evaluate()` 是同步方法，内部遍历 `activeModes` 并调用 `modeHandlers`。在多 agent 场景下，如果多个 `Task` 同时调用 `activate/deactivate/toggle/evaluate`，即使序列化到 MainActor 也会产生交错状态读取。本测试验证竞争条件下的状态不变量。

### TC-CR-01：多 Task 同时激活/去激活同一种模式

**步骤**
1. 创建共享 `ModeManager` 实例
2. 启动 10 个并发 Task，每个 Task 对 `OperationMode.readOnly` 交替执行 50 次 `activate()` 和 `deactivate()`
3. 全部 Task 完成后，读取最终 `isActive(.readOnly)` 状态
4. 读取 `config.activeModes` 集合

**预期结果**
- 应用最终不崩溃、不触发 `EXC_BAD_ACCESS`
- `config.activeModes` 的 `contains(.readOnly)` 值最终为 `true` 或 `false`，但集合本身不包含重复元素
- `activeModes` 的 `count` 不会因并发插入产生重复

**验收标准**
- 100 次运行零崩溃
- 集合不出现重复元素（`Set` 不变量保持）

### TC-CR-02：Agent A 评估的同时 Agent B 切换模式

**步骤**
1. 创建共享 `ModeManager`，激活 `.readOnly`
2. Agent A 启动一个持续 `evaluate()` 循环（1000 次，混合高风险/低风险 action）
3. Agent B 同时执行 50 次 `toggle(.readOnly)`（即反复开关只读模式）
4. 记录每次 `evaluate()` 结果

**预期结果**
- 无崩溃或无死锁
- `evaluate()` 返回的结果始终是合法状态：当 `isActive(.readOnly) == true` 时 `blockedBy` 才为 `.readOnly`
- 不存在交替过程中返回部分更新状态（例如 `.activeModes` 已插入但 handler 未就绪）

**验收标准**
- 所有 1000 次评估结果与 `isActive(.readOnly)` 在逻辑上一致
- 0 次不一致

### TC-CR-03：ActionEngine 同时创建、审批、执行、取消

**步骤**
1. 创建共享 `ActionEngine`
2. 启动 A、B、C 三个并发 Task：
   - Task A：创建 200 个 action，随机分配高危/低危
   - Task B：对随机 action ID 执行 `approve()` 或 `reject()`
   - Task C：对已审批的 action 执行 `start()` -> `complete()` 或 `fail()`
3. 全部完成后，扫描 `records` 和 `history`

**预期结果**
- 每个 record 的状态机转换合法（pending -> approved -> executing -> completed，不允许 pending -> completed 等非法跃迁）
- 没有 orphan record（创建后既不在 records 也不在 history）
- 所有 `cancel()` 调用仅在 pending 或 executing 状态成功，已 completed 的返回 false

**验收标准**
- 非法状态跃迁次数 = 0
- 所有 action 的状态转换路径均在合法范围内
- 无数据丢失

### TC-CR-04：ContextManager 并发刷新 + snapshot 读

**步骤**
1. 创建 `ContextManager`，注入一个带有可控延迟的 mock provider（`captureScreenContext` 固定延迟 100ms）
2. 启动 5 个 Task 并发调用 `refresh()`
3. 同时启动 5 个 Task 循环读取 `snapshot()` 和 `summary()`
4. 等待所有 Task 完成

**预期结果**
- 无 `DataRace` 警告（Swift 6.2 严格并发检查通过）
- `lastContext` 在每次 `refresh()` 完成后被完整覆盖，不存在读到了半初始化的 `SystemContext`
- `summary()` 不会因 `lastContext` 为 nil 而崩溃

**验收标准**
- 零线程安全检查失败
- 所有 snapshot 读取操作不崩溃

### TC-CR-05：多 agent 同时 lock/unlock 同一个模式

**步骤**
1. 创建共享 `ModeManager`
2. 5 个并发 Task，每个 Task 对 `.policyLock` 执行 `lock()` 然后 `unlock()`，重复 50 次
3. 结束后验证 `lockedModes` 集合

**预期结果**
- 不崩溃
- 最终 lockedModes 为空（因为 unlock 次数应等于 lock 次数）

**验收标准**
- 最终 lockedModes.count == 0
- 中间没有导致 lockedModes 中出现重复条目

---

## 2. 状态一致性测试

### 设计思路

现有测试验证了单个操作的状态转换，但未覆盖完整的跨组件状态一致性。特别是操作完整生命周期完成后，ModeManager 的评估策略应与 ActionEngine 的实际操作记录匹配，且审计日志的时间戳应连续。

### TC-SC-01：操作生命周期完成后状态机一致性

**步骤**
1. 创建 `ActionEngine`
2. 对一个 action 执行完整的生命周期：create -> approve -> start -> complete
3. 对另一个 action 执行：create -> approve -> start -> fail
4. 对第三个 action 执行：create -> cancel
5. 验证每个 action 的 `status`、`auditTrail` 中每个 entry 的 `event` 序列

**预期结果**
- completed action 的 auditTrail 事件序列为 `["created", "approved", "started", "completed"]`
- failed action 的 auditTrail 事件序列为 `["created", "approved", "started", "failed"]`
- cancelled action 的 auditTrail 事件序列为 `["created", "cancelled"]`
- 完成、失败、取消的时间戳非空且合理（完成时间 >= 创建时间）
- 已完成 action 不在 `records` 中（已完成 action 会被移入 `_history`）

**验收标准**
- 所有状态机序列严格匹配预期
- 时间戳单调递增

### TC-SC-02：模式切换后评估策略一致性

**步骤**
1. 创建 `ModeManager`
2. 依次执行以下操作序列，每次切换后立即 `evaluate()` 同一 action:
   - 初始态 -> evaluate("write", .medium)
   - activate(.readOnly) -> evaluate("write", .medium)
   - deactivate(.readOnly) -> evaluate("write", .medium)
   - activate(.highRisk) -> evaluate("write", .critical)
   - lock(.readOnly) -> evaluate("write", .medium)

**预期结果**
- 初始态：allowed == true
- 激活 .readOnly：allowed == false, blockedBy == .readOnly
- 取消 .readOnly：allowed == true
- 激活 .highRisk：.critical 操作被阻塞，blockedBy == .highRisk
- lock(.readOnly)：allowed == false, blockedBy == .readOnly（且不能 deactivate）

**验收标准**
- 每一步评估结果与当前激活态严格一致
- lock 后即使尝试 deactivate，评估结果仍反映 lock 状态

### TC-SC-03：审计日志与实际操作匹配

**步骤**
1. 创建 `ActionEngine` 和 `ModeManager`
2. 模拟一次完整对话：创建 10 个 action，mix 各种状态转换
3. 导出每个 action 的 `auditTrail`
4. 验证 audit entry 中记录的 event 顺序与实际的 `approve/start/complete/reject/cancel` 操作序列一致

**预期结果**
- 每个 action 的 auditTrail 是操作历史的不可变记录
- audit entry 的 `detail` 字段包含有意义的信息（不是空字符串）
- 所有 entry 的 `timestamp` 是单调递增的

**验收标准**
- auditTrail 长度等于该 action 经历的状态转换次数 + 1（初始 created）
- 事件序列合法
- 时间戳严格递增

### TC-SC-04：上下文快照时间戳连续性

**步骤**
1. 创建 `ContextManager`，使用 mock provider
2. 连续调用 `refresh()` 5 次，间隔 100ms
3. 记录每次的 `capturedAt`
4. 验证所有子快照（screen、app、window、focus 等）的 `capturedAt` 与顶层 `SystemContext.capturedAt` 的关系

**预期结果**
- 每次 refresh 后 `capturedAt` 严格递增
- 所有子快照的时间戳一致（或差异在一个合理的小范围内，如 < 50ms）
- 不存在时间倒流或长时间停滞

**验收标准**
- 5 次 refresh 的 `capturedAt` 单调递增
- 最大时间差 < 1 秒

### TC-SC-05：HealthStatus 缓存刷新一致性

**步骤**
1. 创建 `ContextManager`，使用 mock provider
2. 设置 `cacheExpiry` 为 2 秒
3. 在 5 秒内每 500ms 调用一次 `healthStatus()`
4. 记录每次返回的值和 `cachedHealth`/`healthTimestamp`

**预期结果**
- 在缓存有效期内（2 秒内），连续调用返回同一个 cachedHealth 实例
- 缓存过期后，下一次调用触发重新捕获
- refresh 不会清除 health 缓存（两个缓存独立）

**验收标准**
- 缓存命中率 > 60%（即 2/3 以上的调用应使用缓存）
- 过期后正确刷新

---

## 3. 边界注入测试

### 设计思路

针对 ModeManager、ActionEngine、ContextProvider 的字符串/数值边界进行压力注入，验证系统在极端输入下的稳定性。

### TC-BI-01：超长字符串作为模式名称/操作描述

**步骤**
1. 创建 `ModeManager`，通过 `registerHandler(for:handler:)` 注册自定义 handler
2. `for:` 参数传入 `OperationMode(rawValue: String(repeating: "X", count: 100_000))`
3. 创建 `ActionEngine`，`create(type:preview:targetContext:)` 的 type 和 preview 填充 100 万字符
4. 尝试对超长 action 执行 approve -> start -> complete

**预期结果**
- 超长 `OperationMode` 注册不崩溃（可能返回 nil 的 rawValue，需处理）
- 超长 action 创建不崩溃
- 超长 preview 在审计日志中以截断形式或原样存储，不导致溢出
- `summary()` 或 `getRecentHistory()` 不因超长内容崩溃

**验收标准**
- 0 崩溃
- 审计日志可正常导出

### TC-BI-02：特殊字符在审计日志中

**步骤**
1. 创建 `ActionEngine`
2. 在 action 的 type、preview、targetContext 中包含以下特殊字符：`<script>alert('xss')</script>`、`../../../etc/passwd`、零宽空格 `​`、emoji 序列 `👨‍👩‍👧‍👦`、控制字符 `\x00\x01\x02`、SQL 注入 `' OR 1=1--`
3. 对每个 action 执行完整生命周期
4. 导出审计日志

**预期结果**
- 所有特殊字符被正确存储，不截断、不出错
- 审计日志 JSON 序列化/反序列化后内容不变（round-trip）
- 控制字符不触发终端/日志系统转义问题

**验收标准**
- JSON round-trip 后所有字符保持不变
- 无编码异常

### TC-BI-03：负数/越界值作为风险等级

**步骤**
1. `ActionRiskLevel(rawValue: -1)` —— 验证是否返回 nil
2. `ActionRiskLevel(rawValue: 999)` —— 验证是否返回 nil
3. `ActionEngine.complete(id, result:)` 传入 nil 作为 result
4. `ActionEngine.fail(id, reason:, recovery:)` 传入空字符串
5. `ContextManager.setCacheExpiry(-5.0)` —— 负数缓存时间

**预期结果**
- `ActionRiskLevel(rawValue: -1)` 返回 nil（安全失败）
- `ActionRiskLevel(rawValue: 999)` 返回 nil
- `complete()` 传入 nil result 成功或优雅处理
- 负数 cacheExpiry 被设为 0 或绝对值（不导致无限缓存）
- 系统不崩溃

**验收标准**
- 所有越界输入以 fail-fast 或 fail-safe 方式处理
- 不进入未定义行为

### TC-BI-04：空数据作为上下文快照

**步骤**
1. 创建 `ContextManager`，注入一个全部返回默认值（空字符串、nil、0）的 mock provider
2. 调用 `refresh()`、`snapshot()`、`summary()`
3. 对所有子快照访问属性

**预期结果**
- 空上下文快照的 `summary()` 输出应为正常摘要（只显示非空字段）
- `SystemContext` 的 Equatable 和 Codable 对空数据工作正常
- DevContext 同理

**验收标准**
- 零崩溃
- `summary()` 输出不包含非法格式

### TC-BI-05：极高频率操作（1000 次/秒）

**步骤**
1. 在单独测试函数内（非性能测试），创建 `ActionEngine`
2. 在 1 秒内模拟 1000 个 action 的创建、审批、执行、完成
3. 使用 `Date()` 记录耗时
4. 检查审计日志和时间戳

**预期结果**
- 1000 次操作完成后内存可接受（不激增至 > 50 MB 增量）
- 所有 action ID 唯一（无 UUID 碰撞）
- 审计日志时间戳区分到毫秒级
- 操作不相互覆盖

**验收标准**
- 0 个 action ID 重复
- 操作吞吐量 >= 800 ops/s
- 无数据丢失

---

## 4. 幂等性测试

### 设计思路

验证多次相同输入产生的输出一致（无副作用累积）。

### TC-ID-01：相同操作重复执行结果一致

**步骤**
1. 创建 `ActionEngine`
2. 创建 type、preview、riskLevel 完全相同的 action 3 次
3. 观察每次创建的 ID 是否不同

**预期结果**
- 每次 `create()` 返回的 ID 不同（UUID 唯一）
- 三个 action 在 records 中各有一条独立条目
- 状态完全独立 —— 审批其中一个不影响其他两个

**验收标准**
- 三个 ID 互不相同
- 三个 record 互不干扰

### TC-ID-02：同一模式重复切换后状态一致

**步骤**
1. 创建 `ModeManager`
2. 对 `.readOnly` 重复执行 50 次 `toggle()`
3. 最终状态：如果是偶次 toggle，应为 false；奇次应为 true
4. 验证 `isActive(.readOnly)`

**预期结果**
- 50 次（偶次）后 `.readOnly` 未激活
- `config.activeModes` 中无重复条目

**验收标准**
- 最终状态与 toggle 次数的奇偶性一致
- 集合不变量保持

### TC-ID-03：同一审计查询多次结果一致

**步骤**
1. 创建 `ActionEngine`，创建 5 个 action，执行混合状态转换
2. 固定时间点 T
3. 在 T、T+1s、T+2s 对同一个 action ID 调用 `getAuditTrail(id)` 和 `getRecord(id)`
4. 比较三次结果

**预期结果**
- 在 action 状态不再变化后，`getAuditTrail()` 返回的 `[AuditEntry]` 完全一致（内容、顺序、时间戳相同）
- `getRecord()` 返回的 record 字段完全一致

**验收标准**
- 三次查询结果深相等
- 审计日志不可变

### TC-ID-04：多次 lock/unlock 后状态一致

**步骤**
1. 创建 `ModeManager`
2. 对 `.readOnly` 执行：lock() -> unlock() -> lock() -> unlock()
3. 验证 `lockedModes` 不含 `.readOnly`，`isActive(.readOnly)` 为 false
4. 然后 activate(.readOnly)，再执行同样 lock/unlock 序列
5. 验证最终状态

**预期结果**
- 经过配对 lock/unlock 后，最终 lockedModes 和 activeModes 状态与初始一致
- 多轮操作幂等

**验收标准**
- 配对 lock/unlock 的后置条件保持

### TC-ID-05：多次 evaluate 一致性

**步骤**
1. 创建 `ModeManager`，激活 `.readOnly` + `.noMouse`
2. 在 20 个不同时间点对相同 action "click" + riskLevel .medium 调用 `evaluate()`
3. 记录每次结果

**预期结果**
- 在不切换模式的前提下，20 次 evaluate 结果完全一致
- `allowed`、`blockedBy`、`requiresConfirmation`、`effectiveRiskLevel`、`maskingRequired` 全部相同

**验收标准**
- 20 次结果全等

---

## 5. 资源泄漏测试

### 设计思路

ActionEngine 内部使用 `_records: [String: ActionRecord]` 和 `_history: [ActionRecord]`。ContextManager 的 `cachedComponents` 字典没有显式清理机制。本测试验证长时间/高负载下资源回收情况。

### TC-RL-01：ActionEngine 长时间运行后 records 和 history 增长

**步骤**
1. 创建 `ActionEngine`
2. 在循环中创建 10,000 个 action，每个执行完整生命周期（create -> approve -> start -> complete）
3. 每次循环后记录 `records.count` 和 `history.count`
4. 验证完成后 records 的 size

**预期结果**
- 已完成 action 从 `_records` 移入 `_history`，`_records` 不应持续增长（当前代码中 complete() 会将 record 追加到 `_history`，但 `_records[id]` 仍然保留该 record —— 这是潜在泄漏）
- `_records` 增长应与未完成的 action 数成正比，不与总创建数成正比
- 如存在泄漏，应在报告中标记

**验收标准**
- `records.count` 在 10,000 次完成后 < 100（对应可能的重试状态）
- 或者检测到泄漏并提出修复建议
- 内存增量 < 10 MB

### TC-RL-02：ContextManager 缓存未释放

**步骤**
1. 创建 `ContextManager`
2. 在循环中 100 次调用 `refresh()`，每次产生不同上下文内容
3. 检查 `cachedComponents` 字典的 size

**预期结果**
- `cachedComponents` 在每次 refresh 后应当更新而非无限追加（当前代码中 refresh 直接赋值 `lastContext`，但 `cachedComponents` 从未清理 —— 潜在泄漏）
- 如果每次 refresh 新增 key-value 而不删除旧的，100 次后 `cachedComponents` 不应仅增长，而应维持固定大小

**验收标准**
- `cachedComponents.count` 稳定在常数（不应线性增长）
- 若检测到线性增长，标记为泄漏

### TC-RL-03：DevContextManager 同样泄漏检查

**步骤**
1. 创建 `DevContextManager`
2. 循环 100 次调用 `refresh()`
3. 检查 `lastContext` 赋值

**预期结果**
- 与 ContextManager 类似，`lastContext` 被覆盖而非追加
- 无隐藏泄漏

**验收标准**
- 内存占用稳定

### TC-RL-04：频繁模式切换后内存/CPU 情况

**步骤**
1. 创建 `ModeManager`
2. 对所有 10 种模式交替激活/去激活 500 次
3. 每次激活后调用 `evaluate()` 一次
4. 完成后测量进程内存增量

**预期结果**
- 所有操作在内存中完成
- `modeHandlers` 字典不因模式切换而增长（只注册一次）
- 500 次切换后内存增量 < 1 MB

**验收标准**
- 无 handler 重复注册导致的内存增长
- CPU 时间合理

### TC-RL-05：onStatusChange 闭包循环引用检查

**步骤**
1. 创建 `ActionEngine`
2. 设置 `onStatusChange` 闭包捕获 `ActionEngine` 自身（模拟潜在循环引用）
3. 执行 action 生命周期
4. 使用弱引用检查 engine 是否可释放

**预期结果**
- 闭包使用 `[weak self]` 或 `[unowned self]` 避免循环引用
- 否则应在报告中标记为潜在泄漏

**验收标准**
- 标记循环引用风险（或验证已使用弱引用）

---

## 6. 用户认知测试

### 设计思路

这些测试不在 Swift 单元测试中运行，而是使用人工评估清单。验证非技术用户对安全模式的提示、错误消息、确认对话框的理解程度。

### TC-UC-01：非技术用户理解模式切换提示

**消息样本**

| 模式 | 当前提示 |
|------|---------|
| readOnly | "只读模式：所有写操作被拦截，仅允许读取" |
| suggest | "建议模式：仅提供建议，不执行任何操作" |
| highRisk | "高风险确认模式：高风险操作需要用户确认" |

**评估步骤**
1. 找 5 名非技术背景用户（非开发者、非运维人员）
2. 在不提供额外说明的情况下，显示每个模式的标题和描述
3. 询问：
   - "你认为这个模式下 AI 能做什么、不能做什么？"
   - "如果你开启这个模式，你期望发生什么？"
   - "关闭这个模式后，AI 的行为会恢复到什么状态？"

**预期结果（验收标准）**
- > 80% 的用户能正确描述该模式限制了什么
- > 70% 的用户能说出切换到该模式后的关键行为变化
- 任何用户不会因为描述而产生相反的理解（例如认为"只读模式"允许删除）

### TC-UC-02：错误消息是否可操作

**消息样本**
- ActionEngine reject 时的消息: "not needed" / "手动拒绝"
- ActionEngine fail 时的消息: "crash" / "网络超时" / "Permission denied"
- fail 时的 recoverySuggestion: "retry" / "检查网络连接后重试" / "Check permissions"

**评估步骤**
1. 显示每条错误消息给 5 名用户
2. 询问：
   - "你明白发生了什么吗？"
   - "下一步你会怎么做？"
   - "这个消息是否告诉了你如何修复？"

**预期结果（验收标准）**
- 有 recoverySuggestion 的消息：> 80% 用户知道下一步操作
- 无 recoverySuggestion 的消息：> 50% 用户感到困惑、"不知道该怎么做"
- 建议改进：所有 fail 场景必须携带可操作的 recoverySuggestion
- 中文错误消息比英文消息理解率高出至少 30%（目标用户为中文用户）

### TC-UC-03：确认对话框是否明确

**场景**
- ModeManager evaluate 返回 `requiresConfirmation: true`
- ActionEngine approve 前的确认提示

**评估步骤**
1. 模拟一个高危操作："删除 /Users/test/document.txt"（riskLevel: .critical）
2. 显示确认对话框文本："高风险操作需要确认。操作：删除文件。风险等级：严重。"
3. 询问用户：
   - "你清楚你将要允许什么吗？"
   - "你知道这个操作可能造成什么影响吗？"
   - "你会点击确认还是取消，为什么？"

**预期结果（验收标准）**
- > 90% 用户能准确说出将要发生什么
- 对话框内容包含：操作类型、目标、风险等级、潜在影响
- 不包含技术术语（如 auditTrail、ActionRecord 等）

### TC-UC-04：模式切换时的安全预期

**评估步骤**
1. 向用户展示场景："你正在编辑一份重要文档，AI 助手突然说它要切换到'只读模式'"
2. 询问：
   - "你觉得为什么 AI 要主动切换模式？"
   - "你担心什么？"
   - "如果模式切换后你的文档不见了，你会怪谁？"

**预期结果（验收标准）**
- 用户应理解模式切换是安全机制而非故障
- 如果用户产生负面归因（如"AI 自作主张"），说明需要增加模式切换的透明度
- 建议改进：AI 主动切换模式时应附带原因和用户确认步骤

### TC-UC-05：跨模式组合理解

**场景**
1. 同时激活 `.readOnly` + `.noMouse` + `.autoMask`
2. 向用户展示模式组合列表

**评估步骤**
1. 询问用户："如果同时开启这三个模式，AI 还能做什么？"
2. 列举几个操作让用户判断是否允许：
   - "读取当前屏幕内容"
   - "点击登录按钮"
   - "输入密码到文本框"
   - "发送网络请求"

**预期结果（验收标准）**
- > 70% 用户正确判断"读取屏幕"是允许的
- > 80% 用户正确判断"点击"被禁止
- > 60% 用户理解"输入密码"会遇到自动遮蔽
- 如果准确率低于上述阈值，需要改进模式组合的说明方式（例如改用对比表格）

---

## 测试优先级与推荐执行顺序

| 优先级 | 测试分组 | 理由 |
|--------|---------|------|
| P0 | 2. 状态一致性测试 | 现有测试覆盖最弱，且状态不一致会直接导致安全漏洞 |
| P0 | 3. 边界注入测试 | 崩溃类 bug 最容易被边界输入触发 |
| P1 | 1. 并发竞争测试 | MainActor 提供一定保护，但高并发仍有隐患 |
| P1 | 4. 幂等性测试 | 幂等性问题影响用户体验，但不直接导致数据丢失 |
| P2 | 5. 资源泄漏测试 | 泄漏为渐进问题，短期不致命，但需长期监控 |
| P2 | 6. 用户认知测试 | 需要人工资源，但长期影响产品可用性 |

## 建议新增 Test Target

基于本测试计划中的非 UI 测试，建议在 `Package.swift` 中新增以下 test target：

```swift
.testTarget(
    name: "DeepTestPlanV2",
    dependencies: [
        "RenJistrolyEnterprise",
        "RenJistrolyModels",
    ],
    swiftSettings: [.enableUpcomingFeature("InternalImportsByDefault")]
)
```

`tag` 分配：
- `manual`（TC-UC-01 至 TC-UC-05 —— 需人工评估）
- `longrunning`（TC-RL-01、TC-RL-02、TC-RL-05 —— 长时间运行）
- 其余无 tag，纳入标准 CI

---

## 现有测试覆盖缺口总结

| 测试类别 | 现有覆盖 | 本计划补充 |
|---------|---------|-----------|
| 并发竞争 | PerformanceTests 中仅性能测量，无正确性断言 | TC-CR-01 至 TC-CR-05 |
| 状态一致性 | 单组件基础状态转换测试 | TC-SC-01 至 TC-SC-05，跨组件 |
| 边界注入 | StateMachineStressTests 中仅有超长输入 | TC-BI-01 至 TC-BI-05，系统性 |
| 幂等性 | 无 | TC-ID-01 至 TC-ID-05 |
| 资源泄漏 | PerformanceTests 峰终内存检查 | TC-RL-01 至 TC-RL-05 |
| 用户认知 | HumanInteractionTests 仅技术性 | TC-UC-01 至 TC-UC-05，人工评估 |
