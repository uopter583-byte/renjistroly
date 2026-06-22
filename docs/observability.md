# 可观测性方案

## 1. 日志系统

### 日志级别

`debug` / `info` / `warning` / `error` / `fatal`

所有日志输出为 JSON 结构化格式，每行一条记录，包含时间戳、级别、模块、消息和上下文。

### 日志分类

| 文件 | 用途 | 保留策略 |
|------|------|----------|
| `operation.log` | 所有操作记录 | 每日轮转，保留 30 天 |
| `audit.log` | 高风险操作（权限提升、模式切换、配置变更） | 每日轮转，保留 90 天 |
| `error.log` | 错误和异常（包括 warning 以上级别） | 100MB 轮转，保留 10 份 |
| `access.log` | MCP 工具调用记录（工具名、参数摘要、耗时） | 每日轮转，保留 14 天 |

### 日志轮转

- 按时间轮转：每天 00:00 切割
- 按大小轮转：单文件达 100MB 自动切割
- 使用系统 `newsyslog` 或应用内 `rolling-file-appender` 驱动

### 脱敏规则

所有日志写入前经过 `CredentialSanitizer` 处理，覆盖：
- API Key / Token（正则匹配替换为 `***`）
- 文件路径中的用户名
- 屏幕内容截图中的人脸区域（起用前灰度化标记）

---

## 2. 指标系统

### 基础指标

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `operation.total` | Counter | 操作总次数 |
| `operation.success` | Counter | 成功次数 |
| `operation.duration_ms` | Histogram | 操作延迟分布 |
| `operation.error` | Counter | 错误次数，按错误类型标签 |

### 安全指标

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `security.blocked` | Counter | 被拦截的操作次数 |
| `security.high_risk_op` | Counter | 高风险操作执行次数 |
| `security.mode_switch` | Counter | 权限模式切换次数 |

### 性能指标

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `performance.ocr_duration_ms` | Histogram | OCR 请求延迟 |
| `performance.ax_capture_duration_ms` | Histogram | AX 树捕获延迟 |
| `performance.context_assembly_duration_ms` | Histogram | 上下文组装延迟 |

### 健康指标

| 指标名 | 类型 | 说明 |
|--------|------|------|
| `health.uptime_seconds` | Gauge | 进程存活时间 |
| `health.memory_rss_mb` | Gauge | 内存占用 |
| `health.cpu_percent` | Gauge | CPU 使用率 |
| `health.permission_ax` | Gauge | 辅助功能权限状态（1=正常） |
| `health.permission_screen_recording` | Gauge | 屏幕录制权限状态（1=正常） |

指标收集周期：基础/安全/健康指标每 15 秒采样一次，性能指标按请求触发。

---

## 3. 健康检查

通过 MCP 工具 `/health` 暴露：

```json
{
  "status": "ok" | "degraded" | "down",
  "uptime_seconds": 3600,
  "memory_rss_mb": 120,
  "cpu_percent": 2.5,
  "permissions": {
    "accessibility": true,
    "screen_recording": true
  },
  "last_operation": {
    "success": true,
    "duration_ms": 450,
    "timestamp": "2026-06-19T10:00:00Z"
  },
  "components": [
    {"name": "process_alive", "status": "ok"},
    {"name": "ax_privilege",  "status": "ok"},
    {"name": "screen_recording", "status": "ok"}
  ]
}
```

健康检查每 30 秒自动触发一次，状态变更时写入 `operation.log`。

---

## 4. 告警规则

| 规则 | 条件 | 严重级别 | 动作 |
|------|------|----------|------|
| 连续操作失败 | 同类型操作连续失败 >= 5 次 | warning | 记录 error.log + 通知 |
| OCR 延迟过高 | OCR 延迟 > 5s | warning | 记录 error.log |
| 高风险拦截过多 | 高风险操作被拦截 > 10 次/小时 | critical | 记录 audit.log + 通知 |
| 内存超限 | RSS > 500MB | critical | 触发 GC 提示 + 记录 error.log |
| 权限丢失 | AX 或屏幕录制权限从 true 变为 false | critical | 记录 audit.log + 通知 |

告警阈值初始基于经验设定，上线后根据实际数据调整。

---

## 5. 仪表盘

### 实时操作面板

- 最近 100 条操作流（自动滚动）
- 操作成功率环形图
- 平均延迟趋势线（最近 5 分钟）

### 安全事件时间线

- 时间粒度可缩放（1 小时 / 24 小时 / 7 天）
- 高风险操作、拦截事件、模式切换事件混排显示
- 点击事件可展开查看完整上下文（脱敏后）

### 系统健康状态

- 四个指示灯：进程、AX 权限、屏幕录制、内存
- 内存 / CPU 时间序列（最近 1 小时）
- 组件状态变更历史

仪表盘通过本地 Web 界面提供，端口 19200，仅监听 localhost。
