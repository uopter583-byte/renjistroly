# 企业快速入门 — IT 管理员 5 分钟指南

## 1. 安装 RenJistroly

从发布页下载最新 `.dmg` 或通过内部 MDM 分发。将应用拖入 `/Applications`。

```bash
# 验证签名
spctl --assess --verbose /Applications/RenJistroly.app
```

确保终端用户启动后允许「RenJistroly」在登录时自动运行（系统设置 > 通用 > 登录项）。

## 2. 授予权限

RenJistroly 需要两项系统权限：

- **辅助功能权限**：系统设置 > 隐私与安全性 > 辅助功能 > 勾选 RenJistroly
- **屏幕录制权限**：系统设置 > 隐私与安全性 > 屏幕录制 > 勾选 RenJistroly

首次启动会自动弹出权限提示。若被拒绝，手动添加后重启应用。可通过 MDM 配置文件提前授权：

```xml
<key>PPPUtilityServices</key>
<array><string>com.renjistroly.app</string></array>
```

## 3. 选择初始安全模式

建议首次部署时启用**只读模式**，避免 AI 助手误执行写操作：

```swift
modeManager.activate(.readOnly)
modeManager.activate(.auditExport)  // 同时开启审计
```

后续可根据角色切换为 `executable`（标准操作）或 `suggest`（仅建议）。

## 4. 验证操作

打开终端，确认模式已生效：

```bash
# 查看当前激活模式（通过 MCP 工具查询）
renjistroly mode status
# 预期输出示例：readOnly, auditExport
```

尝试一条非破坏性操作，确认 `evaluate()` 返回 `allowed: false` 且 `blockedBy: .readOnly`。

## 5. 配置管理员策略

通过 `ModePolicy` 锁定安全边界：

- 设置 `maxRiskLevel: .low` 禁止高风险操作
- 添加 `blockedDomains` 限制网络访问范围
- 设置 `auditRetentionDays: 365` 保留一年审计记录
- 使用 `lock(_:)` 锁定核心模式，防止用户绕过

```swift
var policy = ModePolicy.default
policy.maxRiskLevel = .low
policy.blockedDomains = ["external-ai.com"]
policy.auditRetentionDays = 365
modeManager.setPolicy(policy)
modeManager.lock(.readOnly)
modeManager.lock(.policyLock)
```

完成以上五步即可安全部署 RenJistroly 到企业环境。
