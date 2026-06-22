# RenJistroly 错误消息中文翻译对照表

> 扫描范围：Sources/ 下所有 .swift 文件中的用户可见错误/警告/提示消息
> 扫描日期：2026-06-19
> 总计：38 条

| 英文消息 | 中文翻译 | 出现文件 | 场景 |
|----------|---------|---------|------|
| `"Your Mac Operating Agent"` | "您的 Mac 操作代理" | ProductIdentity.swift | 产品标语 |
| `"Missing tool name or id"` | "缺少工具名称或 ID" | MCPBridge.swift | MCP 调用校验 |
| `"Method not found: \(method)"` | "找不到方法：\(method)" | MCPBridge.swift | MCP 路由 |
| `"Tool execution failed: \(error.localizedDescription)"` | "工具执行失败：\(error.localizedDescription)" | MCPBridge.swift | MCP 工具执行 |
| `"stdin closed, exiting"` | "标准输入已关闭，正在退出" | MCPBridge.swift | MCP 生命周期 |
| `"missing text"` | "缺少文本参数" | MCPBridge.swift | 语音合成参数校验 |
| `"app not running: \(app)"` | "应用未运行：\(app)" | AccessibilityBridge.swift | AX 目标查找 |
| `"Unknown App"` | "未知应用" | AccessibilityContextProvider.swift | 应用名回退 |
| `"unknown"` | "未知" | AppleScriptBridge.swift | AppleScript 错误回退 |
| `"Unknown"` | "未知" | AppleScriptBridge.swift | 前台应用名回退 |
| `"🔴 PRODUCTION"` | "🔴 生产环境" | EnvironmentDistinguisher.swift | 环境标签 |
| `"🟡 STAGING"` | "🟡 预发布环境" | EnvironmentDistinguisher.swift | 环境标签 |
| `"🟢 DEVELOPMENT"` | "🟢 开发环境" | EnvironmentDistinguisher.swift | 环境标签 |
| `"🔵 TESTING"` | "🔵 测试环境" | EnvironmentDistinguisher.swift | 环境标签 |
| `"Safari has no front window"` | "Safari 没有前置窗口" | AppDrivers.swift | AppleScript 错误 |
| `"Chrome has no front window"` | "Chrome 没有前置窗口" | AppDrivers.swift | AppleScript 错误 |
| `"unsafe pattern in: \(trimmed.prefix(60))"` | "命令包含不安全模式：\(trimmed.prefix(60))" | ShellExecutor.swift | 命令安全校验 |
| `"created"` | "已创建" | ActionEngine.swift | 审计事件 |
| `"approved"` | "已批准" | ActionEngine.swift | 审计事件 |
| `"rejected"` | "已拒绝" | ActionEngine.swift | 审计事件 |
| `"started"` | "已开始" | ActionEngine.swift | 审计事件 |
| `"completed"` | "已完成" | ActionEngine.swift | 审计事件 |
| `"failed"` | "已失败" | ActionEngine.swift | 审计事件 |
| `"cancelled"` | "已取消" | ActionEngine.swift | 审计事件 |
| `"rolledBack"` | "已回滚" | ActionEngine.swift | 审计事件 |
| `"Action created"` | "动作已创建" | ActionEngine.swift | 审计详情 |
| `"Action approved"` | "动作已批准" | ActionEngine.swift | 审计详情 |
| `"Action rejected"` | "动作已拒绝" | ActionEngine.swift | 审计详情 |
| `"Execution began"` | "执行已开始" | ActionEngine.swift | 审计详情 |
| `"Action cancelled"` | "动作已取消" | ActionEngine.swift | 审计详情 |
| `"User rejected"` | "用户已拒绝" | ToolExecutionService.swift | 工具执行策略 |
| `"pending"` | "待处理" | ActionEngine.swift | 动作状态标识 |
| `"executing"` | "执行中" | ActionEngine.swift | 动作状态标识 |
| `"element_not_found"` | "元素未找到" | RecoveryDecider.swift | 失败分类 |
| `"snapshot_stale"` | "快照已过期" | RecoveryDecider.swift | 失败分类 |
| `"permission_denied"` | "权限被拒绝" | RecoveryDecider.swift | 失败分类 |
| `"app_unresponsive"` | "应用无响应" | RecoveryDecider.swift | 失败分类 |
| `"action_failed"` | "操作失败" | RecoveryDecider.swift | 失败分类 |

## 附录：已中文化的消息（仅做参考）

以下消息已在代码中写为中文，无需翻译：

| 中文消息 | 英文对应 | 出现文件 |
|----------|---------|---------|
| "只读模式：所有写操作被拦截，仅允许读取" | Read-only mode: all write operations blocked, reads only | ModeManager.swift |
| "高风险操作需要用户确认" | High risk operation requires user confirmation | ModeManager.swift |
| "禁止所有网络调用" | All network calls blocked | ModeManager.swift |
| "敏感字段（密码、密钥等）自动遮蔽" | Sensitive fields auto-masked | ModeManager.swift |
| "管理员策略锁定，不可修改" | Admin policy locked, not modifiable | ModeManager.swift |
| "命令内容为空，请输入要执行的命令。" | Command is empty, please enter a command to execute. | ShellExecutor.swift |
| "命令「\(cmd)」不在允许列表中，已阻止执行。" | Command "\(cmd)" not in allowlist, execution blocked. | ShellExecutor.swift |
| "命令执行超时，请检查命令是否需要更长时间。" | Command execution timed out, please check if it needs more time. | ShellExecutor.swift |
| "需要先开启辅助功能权限" | Accessibility permission required first | AccessibilityBridge.swift |
| "应用无响应" | App is unresponsive | HealthMonitor.swift |
| "屏幕捕获流异常" | Screen capture stream abnormal | HealthMonitor.swift |
| "MCP 服务进程未运行" | MCP service process is not running | HealthMonitor.swift |
| "UI 快照已过期，请先重新 observe/get_app_state" | UI snapshot expired, please re-observe first | ElementRegistry.swift |
| "找不到 UI 元素: \(index)" | UI element not found: \(index) | ElementRegistry.swift |
| "高风险动作需要确认：\(action.humanPreview)" | High-risk action requires confirmation: \(action.humanPreview) | ActionSafety.swift |
| "仅提供建议，不执行任何操作" | Suggestions only, no actions executed | ModeManager.swift |
| "所有敏感文件仅在本机处理" | All sensitive files processed locally only | LocalOnlyPolicy.swift |
| "日志仅驻留内存，关闭会话后自动清除" | Logs reside only in memory, cleared on session close | LogProcessingIsolator.swift |
