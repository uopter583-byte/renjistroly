# 贡献指南

欢迎为 RenJistroly 贡献代码、报告问题或提出改进建议！

## 报告 Bug

如果你发现了 Bug，请通过 GitHub Issues 提交。提交时请包含：

1. **运行环境**：macOS 版本、芯片类型（Apple Silicon / Intel）
2. **复现步骤**：最小化可复现的操作流程
3. **预期行为**：你认为应该发生什么
4. **实际行为**：实际发生了什么，包含完整的错误日志
5. **截图/录屏**（可选）：有助于定位 UI 相关问题

## 功能请求

如有新功能建议，请先搜索现有 Issues 确认是否已有人提出，然后提交新 Issue 并标记为 `enhancement`。

## 提交 Pull Request

### 准备工作

1. Fork 本仓库并克隆到本地
2. 确保你已安装 Xcode 16+ 和 Swift 6.2+
3. 运行 `swift build` 确认项目可编译

### 开发流程

1. 从 `main` 分支创建新分支：
   - 新功能：`feature/简短描述`（如 `feature/dark-mode-support`）
   - Bug 修复：`fix/简短描述`（如 `fix/crash-on-empty-input`）
   - 文档：`docs/简短描述`
2. 在分支上进行开发
3. 确保代码通过编译：`swift build`
4. 运行测试：`swift test`
5. 提交并推送至你的 Fork
6. 创建 Pull Request 至本仓库的 `main` 分支

### PR 规范

- **标题**：简短扼要，概括变更内容（如 "Add local LLM inference via MLX"）
- **描述**：说明变更动机、实现方式和可能的副作用
- **测试**：新增功能应包含单元测试
- **单一职责**：一个 PR 只解决一个问题
- **提交粒度**：每个提交应是一个逻辑完整的变更

### 代码审查

PR 提交后，维护者会尽快审查。审查过程中：

- 保持开放心态，审查意见旨在改进代码质量
- 如需修改，直接在分支上追加提交即可
- 审查通过后，维护者会合并 PR

## 开发环境设置

1. **克隆仓库**
   ```bash
   git clone https://github.com/yourusername/RenJistroly.git
   cd RenJistroly
   ```

2. **编译项目**
   ```bash
   swift build
   ```

3. **运行 MCP 服务器（独立测试）**
   ```bash
   swift build --target RenJistrolyMCP
   .build/arm64-apple-macosx/debug/RenJistrolyMCP
   ```

4. **运行应用**
   ```bash
   Scripts/compile_and_run.sh
   ```

## 沟通渠道

- GitHub Issues：报告 Bug 和功能请求
- Pull Requests：代码贡献与审查

感谢你的贡献！
