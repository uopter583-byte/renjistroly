# 12 种用户角色场景

`ProductIdentity` 定义了 CapabilityLevel 四级分级（观察/读写/自动化/自主），结合 10 种安全模式形成矩阵式角色覆盖。

## 分级模型

| 等级 | 能力 | 典型模式组合 |
|------|------|-------------|
| **observe** (0) | 仅可观察屏幕和 UI | readOnly + noMouse + localOnly |
| **readWrite** (1) | 可读写文件内容 | readWrite + autoMask |
| **automate** (2) | 可执行标准自动化 | executable + highRisk |
| **autonomous** (3) | 可自主决策执行 | executable + auditExport |

## 角色场景

1. **只读观察者** — observe 级，仅查看屏幕内容，不写任何文件。适用：安全审计、演示。
2. **建议咨询师** — observe + suggest 模式，只给建议不执行。适用：培训环境。
3. **内容编辑者** — readWrite + autoMask，可编辑文件但自动遮蔽密钥。适用：普通办公。
4. **桌面自动化执行者** — automate + noMouse，运行脚本但禁用鼠标。适用：CI 环境。
5. **轻度使用者** — executable + localOnly，断网使用。适用：内网开发。
6. **敏感应用操作员** — executable + sensitiveAppBlock，接触密码管理器等 App 时自动防护。适用：运维。
7. **受限开发者** — executable + noMouse + autoMask，开发场景。适用：外包团队。
8. **独立自主代理** — autonomous + auditExport，24 小时无人值守任务。适用：后台作业。
9. **策略锁定终端** — policyLock + readOnly，管理员远程锁定。适用：丢失设备保护。
10. **高权限管理员** — autonomous 级，全功能。适用：设备主人在家使用。
11. **外发审计员** — observe + auditExport，读取并导出操作日志。适用：合规审计。
12. **演示沙箱** — readOnly + localOnly + noMouse + sensitiveAppBlock 全锁。适用：公开演示。

## 权限交叠

角色可复合：一个用户可同时具备多个模式，evaluate() 按序裁决，任一模式阻断则操作被拒绝。
