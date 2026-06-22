# 安全模式配置指南

## 10 种模式详细说明

RenJistroly 提供 10 种可叠加的 `OperationMode`，通过 `ModeManager` 统一管理：

| 模式 | 风险等级 | 效果 | 典型用途 |
|------|---------|------|---------|
| **readOnly** | 低 | 阻断 write/create/delete 等写操作 | 审计、演示环境 |
| **suggest** | 最低 | 所有操作仅建议，不执行 | 咨询、培训场景 |
| **executable** | 中 | 允许标准操作（默认行为） | 日常使用 |
| **highRisk** | 中 | 高风险操作（riskLevel >= .high）需确认 | 平衡效率与安全 |
| **noMouse** | 低 | 禁用鼠标/拖拽操作 | 无人值守或演示 |
| **localOnly** | 高 | 禁止全部网络调用 | 离线环境、敏感数据 |
| **sensitiveAppBlock** | 高 | 阻止读取敏感应用内容 | 财务、HR 终端 |
| **autoMask** | 中 | 密码/密钥等敏感字段自动遮蔽 | 屏幕共享、录屏 |
| **policyLock** | 最高 | 配置不可修改；需管理员解锁 | 远程锁定设备 |
| **auditExport** | 低 | 强制记录全部操作 | 合规审计要求 |

模式叠加时按枚举 `rawValue` 顺序依次评估，首个阻断的模式返回为 `blockedBy`。

## 推荐配置组合（按角色）

### 开发人员
`executable` + `highRisk` — 允许标准操作，破坏性操作需确认。

### 财务/HR
`localOnly` + `sensitiveAppBlock` + `autoMask` + `auditExport` — 防止数据外泄，自动遮蔽敏感字段。

### 访客/演示
`readOnly` + `noMouse` + `auditExport` — 只读演示，禁用鼠标操作。

### 远程/无人值守
`policyLock` + `readOnly` + `localOnly` — 管理员锁定，零信任策略。

## 策略锁定配置

`ModePolicy` 提供细粒度安全策略：

```swift
let lockedPolicy = ModePolicy(
    requiresConfirmation: true,   // 每步确认
    requiresApproval: true,       // 需要管理员审批
    maxRiskLevel: .low,           // 最高仅允许可撤销操作
    auditRetentionDays: 365       // 审计保留一年
)
```

锁定后的模式无法通过 `deactivate()` 移除，必须调用 `unlock(_:)`。

## 审计日志解读

`ModeEvaluation` 是每次操作评估的结果：

- **allowed**: 操作是否允许执行（`false` 表示被阻断）
- **blockedBy**: 阻断该操作的模式名称
- **requiresConfirmation**: 是否需要用户二次确认
- **effectiveRiskLevel**: 受策略限制后的实际风险等级
- **maskingRequired**: 输出是否需要遮蔽敏感字段
- **auditRequired**: 该操作是否记入审计日志

审计日志示例：

```
[2026-06-19 10:32:15] EVALUATE write:file.txt
  → allowed=false, blockedBy=readOnly, risk=.low
[2026-06-19 10:32:20] EVALUATE fetch:https://api.example.com
  → allowed=false, blockedBy=localOnly, risk=.medium
[2026-06-19 10:33:00] EVALUATE click:button
  → allowed=true, maskingRequired=true, auditRequired=true
```

建议将审计日志通过 `auditExport` 模式定期导出至 SIEM 系统。
