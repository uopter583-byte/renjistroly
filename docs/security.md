# 安全架构

## 分层防御

RenJistroly 的安全体系从四个层面构建纵深防御：

### 1. 系统权限层

依赖 macOS 原生权限机制：
- **Accessibility** — AX API 控制，需用户在 系统设置 > 隐私与安全性 中授权
- **Screen Recording** — ScreenCaptureKit 捕获，独立授权
- **Microphone** — 语音输入授权
- **Apple Events** — 自动化授权

所有权限未经用户明确授予即不可用，进程无法静默提升。

### 2. 企业模式层

`ModeManager` 提供 10 种安全模式的运行时可编程阻断：
- 每个模式有独立 `ModeHandler(action, riskLevel) -> Bool` 评估函数
- `ModePolicy` 支持域名/应用级别的白名单和黑名单
- `maxRiskLevel` 限制最大允许风险（low/moderate/high/critical）
- `lockedModes` 不可由用户解除，策略锁定由管理员控制
- 锁定策略（`.locked`）：确认 + 审批 + maxRiskLevel = low + 365 天审计

### 3. 敏感信息防护层

- `autoMask` 模式自动遮蔽密码、密钥等敏感字段
- `sensitiveAppBlock` 禁止读取密码管理器、银行 App 等指定应用的内容
- `sensitiveAppBundleIDs` 可配置，支持自定义敏感应用列表

### 4. 审计追踪层

- 每次操作评估返回 `ModeEvaluation`，含 allowed/blockedBy/requiresConfirmation/maskingRequired
- `auditRequired` 默认 true，强制记录操作日志
- `auditRetentionDays` 可配（默认 90 天，锁定策略 365 天）
- AuditExport 模式专用于日志导出场景

## MCP 安全

RenJistrolyMCP 是独立进程，与 App 通过 stdio JSON-RPC 通信。`MCPToolRegistry` 在注册时即绑定 `evaluate()` 检查，规避未经授权暴露系统接口。

## 执行沙箱

`ShellExecutor` 内部使用受控执行环境。网络请求由 `localOnly` 模式统一管控。权限提升路径（SMJobBless）通过 XPC 协议隔离在 `RenJistrolyHelper` 中。
