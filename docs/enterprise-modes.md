# 10 种安全模式

RenJistroly 的 `ModeManager` 管理 10 种可叠加的操作模式，每个模式有独立的 `ModeHandler` 闭包，在 `evaluate()` 评估时按优先级依次检查。被锁定的模式（`lockedModes`）不可由用户解除。

## 模式一览

| 模式 | 作用 | 阻断规则 |
|------|------|----------|
| **readOnly** | 拦截所有写操作 | write/create/delete/modify/edit/move/copy/rename/save/commit/push |
| **suggest** | 仅提供建议 | 全阻断（handler 返回 false） |
| **executable** | 允许标准操作 | 全放行（handler 返回 true） |
| **highRisk** | 高风险操作需确认 | riskLevel >= .high 时阻断 |
| **noMouse** | 禁用鼠标控制 | click/doubleClick/drag/scroll/moveMouse/rightClick |
| **localOnly** | 禁止网络调用 | fetch/download/upload/api/webRequest/network |
| **sensitiveAppBlock** | 防护敏感 App | readSensitiveApp/captureSensitiveApp |
| **autoMask** | 自动遮蔽敏感字段 | 不阻断，标记 maskingRequired |
| **policyLock** | 策略锁定不可改 | 不阻断，禁止修改 config |
| **auditExport** | 审计导出模式 | 不阻断，强制 auditRequired |

## 模式叠加

多个模式可同时激活，`findBlockingMode()` 按操作名排序依次检查。例如同时启用 readOnly + noMouse，两类操作都会被拦截。

## ModePolicy

- `requiresConfirmation` — 全局确认开关
- `requiresApproval` — 全局审批开关
- `allowedDomains` / `blockedDomains` — 域名白/黑名单
- `allowedApps` / `blockedApps` — 应用白/黑名单
- `maxRiskLevel` — 最大允许风险等级
- `auditRetentionDays` — 审计保留天数

默认策略 maxRiskLevel = critical（全放行），锁定策略降至 low + 强确认。

## 使用场景

- 只读模式用于审计/演示；建议模式用于咨询场景；localOnly 用于离线环境；policyLock 由管理员远程锁定设备。
