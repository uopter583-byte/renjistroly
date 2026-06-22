# Git 仓库初始化报告

## 初始化状态

- **时间**: 2026-06-19
- **仓库**: `/Users/yoming/RenJistroly`
- **Git 版本**: `$(git --version)`
- **初始化**: 已完成 (空仓库初始化，分支: `main`)

## 暂存文件概况

| 项目 | 数值 |
|------|------|
| 暂存文件总数 | 577 |
| 总代码行数 | ~118,497 inserts |
| 磁盘占用 | ~11 MB |

### 按目录分布

| 目录 | 说明 |
|------|------|
| `Sources/` | 核心 Swift 源码 (RenJistroly 各模块) |
| `Tests/` | 单元测试 |
| `docs/` | 文档 (36 个文件) |
| `Scripts/` | 构建与辅助脚本 |
| `Resources/` | 资源文件 (entitlements, assets) |
| `.agents/skills/` | Claude Code 技能定义 |
| `.claude/` | Claude 配置 (i18n, mcp, skills) |
| `.github/` | GitHub Actions 配置 |
| 其他 | `Package.swift`, `README.md`, `CHANGELOG.md` 等 |

## 已排除的大文件/目录

以下因 `.gitignore` 规则不会被跟踪：

| 路径 | 大小 | 说明 |
|------|------|------|
| `.build/` | ~431 MB | SwiftPM 构建产物 |
| `RenJistroly.app/` | ~100 MB | 编译后的 App bundle |
| `RenJistroly-0.1.0.dmg` | ~1.4 MB | 安装 DMG |
| `build/` | ~2.8 MB | 额外构建输出 |
| `_archived/` | ~219 MB | 已归档的旧项目代码 |
| `_vendored/` | ~397 MB | 外部依赖 (aisuite, chatwoot) |
| `Frameworks/` | ~71 MB | 内嵌动态库 (onnxruntime) |
| `stability_logs/` | ~68 KB | 运行时日志 |

**排除总量**: ~1.2 GB (不进入版本控制)

## .gitignore 建议

当前 `/Users/yoming/RenJistroly/.gitignore` 内容如下：

```
.build/
.DS_Store
*.app
*.xcworkspace
*.xcuserdata
DerivedData/
*.dmg
*.ipa

# Build artifacts
build/

# Archived code
_archived/

# Vendored dependencies (use SPM)
_vendored/

# Embedded frameworks (rebuilt from source)
Frameworks/

# Runtime logs
stability_logs/
```

### 进一步建议

如果未来需要更完善的忽略规则，可考虑添加：

- `*.log` — 防止随机日志文件被跟踪
- `*.swp` / `*.swo` — Vim 临时文件
- `.idea/` — JetBrains IDE 配置
- `*.plist` (在非 Resources 路径下) — 避免敏感 plist 泄露
- `Package.resolved` 是否跟踪取决于策略：推荐跟踪以锁定依赖版本

## 分支策略建议

建议采用 **Git Flow** 轻量变体：

```
main         ← 稳定发布版，只接受合并请求
  └─ develop         ← 日常开发主分支
       ├─ feature/xxx     ← 新功能分支 (从 develop 创建)
       ├─ bugfix/xxx      ← 问题修复分支
       └─ release/x.y.z   ← 发布准备分支
```

### 工作流程

1. **main** — 保护分支。只从 `release/*` 或 `hotfix/*` 合并。每次合并对应一个正式版本。
2. **develop** — 主要开发分支。功能分支完成后合并至此。
3. **feature/xxx** — 从 `develop` 创建，完成后 PR 合并回 `develop`。
   - 命名示例: `feature/floating-panel-redesign`, `feature/mcp-tool-audit`
4. **bugfix/xxx** — 从 `develop` 创建，修复后合并回 `develop`。
5. **release/x.y.z** — 从 `develop` 创建，测试通过后合并到 `main` 并打 tag。
6. **hotfix/xxx** — 从 `main` 创建，修复后合并回 `main` 和 `develop`。

### 首次提交建议

当前暂存区包含完整的项目基础，建议首次提交（初始提交）后立即创建 `develop` 分支：

```bash
git commit -m "chore: initial commit - RenJistroly macOS AI Assistant"
git branch develop
git push -u origin main
git push -u origin develop
```

## 下一步

- [ ] 确认暂存内容无误后执行 `git commit`
- [ ] 配置 GitHub remote: `git remote add origin <repo-url>`
- [ ] 推送代码: `git push -u origin main`
- [ ] 创建 develop 分支
- [ ] (可选) 配置 GitHub 分支保护规则 (main 禁止直接推送)
