# 依赖审计报告

**项目**: RenJistroly
**审计日期**: 2026-06-19
**审计范围**: Swift Package Manager 依赖 + 系统级依赖
**工具版本**: swift-tools-version 6.2, macOS 15+, Apple Silicon

---

## 结论概要

| 依赖类型 | 数量 | 风险等级 |
|----------|------|---------|
| SwiftPM 外部依赖 | 0 | 无 |
| 系统级依赖 (Homebrew) | 1 | 低 |
| Vendored (参考用, 非编译) | 2 | 无 |

**核心结论**: 纯 SwiftPM 项目，无外部 Swift 包依赖，风险可控。

---

## 1. Swift Package Manager 依赖

**数量: 0**

`Package.swift` 中未定义任何 `package.dependencies`。所有 18 个 target 仅依赖项目内部模块：

- RenJistrolyModels
- RenJistrolySystemBridge
- RenJistrolyIntelligence
- RenJistrolyCapability
- RenJistrolyConversation
- RenJistrolyUI
- RenJistrolyApp
- RenJistrolyMCP
- RenJistrolyBridge
- RenJistrolyGate
- RenJistrolyHelper
- RenJistrolyEnterprise
- RenJistrolyProductIdentity
- RenJistrolyXPC
- COrt (C 包装层)
- 6 个 test targets

验证确认:

- `workspace-state.json` 的 `dependencies` 数组为空
- 源代码中无任何外部 Swift 包 import 语句
- 所使用的全部为 Apple 系统框架 (Foundation, AppKit, SwiftUI, Combine, ScreenCaptureKit, AVFoundation 等)

**风险**: 无

---

## 2. 系统级依赖

### 2.1 onnxruntime v1.26.0

| 属性 | 值 |
|------|-----|
| **名称** | ONNX Runtime |
| **开发者** | Microsoft |
| **版本** | 1.26.0 (Homebrew cellar: 1.26.0_1) |
| **安装方式** | Homebrew + Frameworks/ 内嵌 dylib |
| **用途** | PP-OCRv6 文字识别引擎 (通过 COrt C 包装层) |
| **License** | MIT |
| **活跃维护** | 是 — 月度发布周期 |

#### 版本状态

- **当前最新版本**: 1.26.0 (2026-05-08 发布)
- **项目使用版本**: 1.26.0
- **状态**: ✅ **最新** — 无需更新

#### 安全风险

| 编号 | 影响版本 | 严重度 | 本版本是否受影响 |
|------|---------|--------|----------------|
| CVE-2026-34445 | ONNX < 1.21.0 | HIGH (8.6) | ❌ 不影响 (ONNX Runtime 1.26.0 已含修复) |
| AIKIDO-2026-10290 | onnxruntime 0.1.4 - 1.24.1 | MEDIUM | ❌ 不影响 (修复于 1.24.2) |
| CVE-2026-0994 | protobuf (transitive) | HIGH (8.6) | ❌ 不影响 (仅 onnxruntime-gpu) |
| CVE-2025-4565 | protobuf (transitive) | HIGH (7.5) | ❌ 不影响 (仅 onnxruntime-gpu) |

**安全总评**: 低风险。当前版本 1.26.0 无已知直接 CVE。

#### License 兼容性

MIT License — 与 RenJistroly 项目兼容。允许使用、修改、分发，需保留版权声明。

#### 替代方案

| 方案 | 说明 | 评估 |
|------|------|------|
| Core ML | Apple 原生 ML 推理框架，无需外部依赖 | 功能不重叠 — onnxruntime 用在 PP-OCRv6，非 Core ML 直接等价 |
| Vision framework | Apple 内置 OCR (VNRecognizeTextRequest) | 可考虑替换，但识别精度和中文支持可能不如 PP-OCRv6 |
| 现有方案维持 | onnxruntime 1.26.0 是最新版，MIT 许可，活跃维护 | ✅ **推荐** |

**建议**: 维持当前方案。未来若 Apple Vision 框架的中文 OCR 精度满足需求，可考虑移除 onnxruntime 以减少外部依赖。

---

## 3. Vendored 目录 (非编译依赖)

以下目录包含第三方项目副本，**仅用于参考/研究目的**，不参与编译，不产生运行时依赖。

### 3.1 _vendored/aisuite

| 属性 | 值 |
|------|-----|
| **项目** | aisuite |
| **类型** | Python AI provider 抽象层 |
| **License** | 待确认 (详见 `_vendored/aisuite/LICENSE`) |
| **当前使用** | 不参与编译，纯参考 |
| **风险** | 无 |

### 3.2 _vendored/chatwoot

| 属性 | 值 |
|------|-----|
| **项目** | Chatwoot |
| **类型** | Ruby on Rails 客户互动平台 (含 JS/TS 前端) |
| **License** | MIT (文件路径: `_vendored/chatwoot/LICENSE`) |
| **当前使用** | 不参与编译，纯参考 |
| **风险** | 无 |

---

## 4. 归档代码 (_archived/)

以下为历史归档文件，不参与当前构建：

- `_archived/renjistroly/` — 早期 Swift 源文件 (语音识别、TTS、权限中心)
- `_archived/mac-voice-assistant/` — 独立语音助手原型项目

**风险**: 无

---

## 5. 综合建议

| 项目 | 建议 | 优先级 |
|------|------|--------|
| onnxruntime 版本 | 维持 1.26.0，关注 upstream 月度更新 | 低 |
| onnxruntime 安全 | 当前无已知 CVE，持续关注 GitHub Advisory | 低 |
| onnxruntime 替代 | 可评估 Apple Vision VNRecognizeTextRequest 是否满足 OCR 需求 | 低 (未来) |
| Vendored 目录 | 清理或明确标注用途，避免混淆未来的开发者 | 低 |
| 引入新依赖 | 如需新增外部 SwiftPM 包，建议先评估 SPM 依赖的供应链风险 | — |

---

## 附录: Apple 系统框架使用清单

以下均为 Apple 内置框架，无外部依赖风险：

Foundation, AppKit, SwiftUI, Combine, Cocoa, CoreGraphics, CoreImage, AVFoundation, NaturalLanguage, Speech, ScreenCaptureKit, UniformTypeIdentifiers, UserNotifications, OSLog, CryptoKit, SystemExtensions, ServiceManagement, IOKit, Carbon, Accessibility, Observation, Testing, XCTest

---

*审计完成。项目总体依赖风险极低。*
