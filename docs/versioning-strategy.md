# 版本管理策略

## 语义化版本（SemVer）

RenJistroly 遵循 [SemVer 2.0](https://semver.org/) 规范，版本号格式为 **MAJOR.MINOR.PATCH**：

| 段位 | 递增时机 | 示例 |
|------|----------|------|
| **MAJOR** | 不兼容的 API 或架构变更 | `1.0.0` → `2.0.0` |
| **MINOR** | 向下兼容的新功能 | `0.1.0` → `0.2.0` |
| **PATCH** | 向下兼容的 Bug 修复 | `0.1.0` → `0.1.1` |

## 开发阶段：v0.x

| 版本 | 状态 | 说明 |
|------|------|------|
| 0.1.x | 早期原型 | 基础能力验证 |
| 0.2.x | 模块化架构 | 核心模块拆分完成 |
| 0.3.x | Enterprise 安全层 | 企业模式 + Product Identity |
| 0.4.x | 生产就绪 | 稳定性 / 性能 / 测试覆盖 |
| 0.5.x – 0.9.x | 预发布 | 功能冻结、Beta 测试 |

v0.x 阶段 **API 不稳定**，MINOR 递增可能包含破坏性变更。所有的 breaking change 必须在 `CHANGELOG.md` 中用 `**BREAKING**` 标记。

## 首个稳定版：v1.0

v1.0.0 的发布条件：

- [ ] 所有核心模块通过生产就绪审计
- [ ] 企业安全模式全面测试通过
- [ ] API 表面稳定，无计划中的破坏性变更
- [ ] CI/CD 流水线完备
- [ ] 测试覆盖率 ≥ 80%
- [ ] 性能基准达标
- [ ] 安全红队测试通过

## BUILD_NUMBER

`BUILD_NUMBER` 为单调递增整数，**每次**版本升级（major / minor / patch）自动 +1。用于：

- `Info.plist` 的 `CFBundleVersion`
- 发版包的构建标识
- 崩溃上报的版本追踪

## 版本文件

版本信息集中存储在项目根目录的 `version.env`：

```bash
APP_NAME=RenJistroly
BUNDLE_ID=com.renjistroly.app
MAJOR=0
MINOR=2
PATCH=0
BUILD_NUMBER=2
APP_VERSION=0.2.0
MARKETING_VERSION=0.2.0
```

`Resources/Info.plist` 通过 CI 或 `Scripts/bump-version.sh` 自动同步。

## 版本升级命令

```bash
# 默认 patch 升级
Scripts/bump-version.sh

# 指定升级类型
Scripts/bump-version.sh patch
Scripts/bump-version.sh minor
Scripts/bump-version.sh major
```

## 与 CHANGELOG 的关联

每次版本号变更应同步更新 `CHANGELOG.md`：

- **新建** `## [新版号] - 日期` 章节
- `[Unreleased]` 链接指向上一个版本 Tag
- 新增版本 Tag 后更新比较链接

### 发版流程

1. `Scripts/bump-version.sh minor` → 版本升至 `0.2.0`
2. 更新 `CHANGELOG.md`，移动 `[Unreleased]` 内容到 `[0.2.0]`
3. `git add version.env Resources/Info.plist CHANGELOG.md`
4. `git commit -m "chore: bump version to 0.2.0"`
5. `git tag 0.2.0`
6. `git push && git push --tags`
