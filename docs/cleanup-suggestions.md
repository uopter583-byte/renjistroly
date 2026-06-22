# 仓库清理建议

> 生成日期：2026-06-19

---

## 一、当前 .gitignore 分析

现有的 `.gitignore` 覆盖范围较好，包含：

```
.build/
.DS_Store
*.app
*.xcworkspace
*.xcuserdata
DerivedData/
*.dmg
*.ipa
build/
_archived/
_vendored/
Frameworks/
stability_logs/
```

大部分典型产物已被忽略，以下针对未覆盖的项和可删除的内容给出建议。

---

## 二、建议补充到 .gitignore

| 模式 | 说明 |
|------|------|
| `*.tmp` | 编译器生成的临时目标文件（`.build/` 下已有，但根目录或其他位置也可能产生） |
| `*.o` | 编译目标文件（现位于 `.build/` 内已被忽略，安全起见可补） |
| `Package.resolved` | 如使用 SPM 且不需要锁定版本，可考虑忽略（当前项目不存在，但团队协作时需决策） |
| `.xcode-version` | Xcode 版本选择文件（可选） |
| `.swiftpm/` | SPM 缓存目录（不存在则忽略） |

建议新增的 `.gitignore` 追加内容：

```
# 临时编译文件
*.tmp
*.o

# Xcode 版本选择
.xcode-version
```

---

## 三、可删除的临时文件

### 3.1 运行时日志 (`stability_logs/`)

| 文件 | 大小 |
|------|------|
| `stability_logs/run_2026-06-19_21-51-58.log` | 运行时日志 |
| `stability_logs/run_2026-06-19_22-07-01.log` | 运行时日志 |
| `stability_logs/launchd_stderr.log` | launchd 错误日志 |
| `stability_logs/launchd_stdout.log` | launchd 标准输出日志 |

这些日志在每次运行后产生，不应保留在仓库目录中（已受 `.gitignore` 保护）。建议定期清理：

```bash
# 安全删除所有运行时日志
rm -f stability_logs/*.log
```

### 3.2 编译临时目标文件

`.build/` 下存在多个 `.tmp` 文件，例如：

- `OCRTool.swift-f600a4fb.o.tmp`
- `RAGEngine.swift-9685f8d0.o.tmp`
- `ComputerUsePlanner.swift-6a43572d.o.tmp`

这些位于已被忽略的 `.build/` 下，不会进入版本控制，但占用磁盘空间。

---

## 四、大文件建议

### 4.1 `.build/` — 构建产物 (63 MB)

- 位置：`./.build/`
- 可安全删除。下次 `swift build` 时会重新生成。
- 如果频繁开发，建议保留以加速增量编译；如果只是查看源码，直接删除。

```bash
rm -rf .build
```

### 4.2 `RenJistroly.app` — 应用包 (100 MB)

- 位置：项目根目录 `./RenJistroly.app`
- 受 `.gitignore` 保护，不会提交到 Git。
- **建议删除**：此为构建产物，根目录下存在一个 100MB 的应用包无意义（编译产物应在 `build/` 下）。
- `build/RenJistroly.app` 仅 2.8 MB（可能是框架外的辅助可执行文件）。

```bash
rm -rf RenJistroly.app
```

### 4.3 `RenJistroly-0.1.0.dmg` — 磁盘映像 (1.4 MB)

- 位置：项目根目录 `./RenJistroly-0.1.0.dmg`
- 受 `.gitignore` 保护。
- **建议删除**：发布版的 DMG 不应存放在源码目录中，应归档到 releases 页面。

```bash
rm RenJistroly-0.1.0.dmg
```

### 4.4 `_archived/` — 已存档代码 (219 MB)

- 位置：`./_archived/`
- 受 `.gitignore` 保护。
- **建议评估后删除**：包含旧版 `mac-voice-assistant` 项目，219 MB 占用较大。如果确实不再需要，删除可显著减少目录大小。

```bash
# 确认不再需要后执行
rm -rf _archived
```

### 大小汇总

| 路径 | 大小 | 建议 |
|------|------|------|
| `RenJistroly.app` | 100 MB | 删除 |
| `.build/` | 63 MB | 按需清理 |
| `_archived/` | 219 MB | 评估后删除 |
| `RenJistroly-0.1.0.dmg` | 1.4 MB | 删除 |
| `build/RenJistroly.app` | 2.8 MB | 保留（已在 `build/` 规则下） |
| stability_logs | < 1 MB | 定期清理 |

合计可释放约 **384 MB**。

---

## 五、保持仓库清洁的建议

1. **日常开发前运行 `swift build --clean-dist`** 可清理构建缓存（或直接 `rm -rf .build`）。
2. **使用 `.gitignore` 模板**：Swift + Xcode 项目使用 GitHub 的 `.gitignore` 模板（[Swift.gitignore](https://github.com/github/gitignore/blob/main/Swift.gitignore)）。
3. **避免在根目录存放构建产物**：`RenJistroly.app` 和 `RenJistroly-0.1.0.dmg` 都不应放在源码根目录。
4. **定期检查仓库大小**：
   ```bash
   # 查看 Git 仓库自身大小
   du -sh .git

   # 查看所有大文件
   git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '/^blob/ {print $NF, $(NF-1)}' | sort -k2 -nr | head -10
   ```
5. **归档策略**：`_vendored/` 已正确忽略，`_archived/` 建议移除或迁移到外部存储。
6. **考虑使用 Git LFS**：如果未来有较大资源文件（模型、音频等），使用 Git LFS 管理，避免仓库膨胀。

---

## 六、推荐的清理命令

一键清理临时和构建产物（不影响源码）：

```bash
# 大构建产物
rm -rf RenJistroly.app
rm RenJistroly-0.1.0.dmg

# 构建缓存
rm -rf .build

# 运行时日志
rm -f stability_logs/*.log

# 已存档代码（确认后）
# rm -rf _archived
```
