# RenJistroly CI/CD 流水线

## 概述

本项目使用 GitHub Actions 实现持续集成和持续交付。流水线定义在 `.github/workflows/` 目录下：

| 文件 | 触发条件 | 作用 |
|------|----------|------|
| `ci.yml` | push 到 `main`/`develop`，所有 PR | 构建验证 + 单元测试 |
| `release.yml` | 推送 `v*.*.*` 格式的 tag | Release 构建 + 打包 + 发布 |

---

## CI 流水线 (`ci.yml`)

### 矩阵策略

- Swift **6.0** 和 **6.1** 两个版本并行构建
- 运行在 `macos-latest` runner 上

### 步骤

1. **Checkout** — 拉取代码
2. **Setup Swift** — 使用 `swift-actions/setup-swift@v2` 安装指定版本
3. **Homebrew 依赖** — 安装 `onnxruntime`（COrt target 需要）
4. **缓存** — 用 `actions/cache@v4` 缓存 `.build/` 目录，加速增量构建
   - 缓存 key 基于 Swift 版本 + `Package.resolved` 哈希
5. **构建** — `swift build`
6. **测试** — `swift test`，跳过 `LongRunningTests` 和 `RegressionTests`

### 跳过测试说明

默认 CI 跳过耗时较长的测试套件。如需在 PR 中手动运行全部测试：

```bash
swift test --skip-test LongRunningTests   # 跳过长时测试
swift test                                # 运行全部
```

---

## Release 流水线 (`release.yml`)

### 触发方式

推送格式为 `v*.*.*` 的 Git tag，例如：

```bash
git tag v0.2.0
git push origin v0.2.0
```

### 步骤

1. **Checkout** — 拉取完整历史（用于 Release Notes）
2. **Setup Swift 6.1** — 固定使用最新 Swift
3. **Homebrew 依赖** — 安装 onnxruntime
4. **缓存** — 同上，但 key 独立（避免与 debug 构建冲突）
5. **Release 构建** — `swift build -c release`
6. **完整测试** — 所有测试套件（包括 LongRunning / Regression）
7. **打包 .app** — 执行 `Scripts/package_app.sh release`
   - 自动使用 ad-hoc 签名（无需开发者证书）
8. **创建 DMG** — 尝试调用 `Scripts/create_dmg.sh`（可选）
9. **上传制品** — `.app` 和 `.dmg` 作为构建 artifact 上传
10. **创建 GitHub Release** — 自动生成 Release Notes，附加 `.app` 和 `.dmg`

### Release 制品

构建完成后可在 GitHub Releases 页面下载：
- `RenJistroly.app` — 完整 .app bundle
- `RenJistroly-*.dmg` — DMG 安装包（如有 `create_dmg.sh`）

---

## 本地依赖说明

`COrt` target 需要 `onnxruntime` Homebrew 包。GitHub Runner 上通过以下命令安装：

```yaml
brew install onnxruntime
```

本地的 `Frameworks/libonnxruntime.1.26.0.dylib` 用于 .app 打包时的 dylib 嵌入，CI 中该文件已在仓库中，打包脚本会直接复制。

---

## 密钥与签名

- CI 构建使用 **ad-hoc 签名**（`-`），无需配置开发者证书
- 如需分发签名的 .app，请在 CI 的 Secrets 中配置：
  - `APPLE_DEVELOPER_ID` — Developer ID Application 证书 SHA-1
  - `APPLE_TEAM_ID` — Apple Team ID
  - `APPLE_ID` / `APPLE_ID_PASSWORD` / `APPLE_TEAM_ID` — 公证（notarization）

然后在 `release.yml` 中设置环境变量 `APP_IDENTITY` 和启用公证步骤。

---

## 故障排除

| 问题 | 原因 | 解决 |
|------|------|------|
| 构建失败：找不到 onnxruntime | Homebrew 未安装 | 检查 brew install 步骤 |
| 测试超时 | LongRunningTests 被包含 | 确认使用了 `--skip-test` |
| 缓存未命中 | `Package.resolved` 不存在 | 运行一次 `swift build` 生成后 `git add Package.resolved` 并提交 |
| Release Release Notes 为空 | tag 无对应 commits | 确保 tag 打在正确的 commit 上 |
