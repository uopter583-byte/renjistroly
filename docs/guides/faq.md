# 常见问题

## 安装与权限

### Q: 打开应用后没有任何反应？
检查以下步骤：

1. 确认 macOS 版本 ≥ 15.0
2. 检查菜单栏是否有 RenJistroly 图标（大脑图标）
3. 按 `Option + Space` 调出浮动面板
4. 如果还是没反应，检查辅助功能权限是否已授予

### Q: 权限已授权但还是提示缺少权限？
1. 检查系统设置中授权的是否是正确路径的应用（RenJistroly.app，不是 Xcode 调试路径）
2. 尝试在权限设置中移除 RenJistroly 再重新添加
3. 重启应用

### Q: 提示检测到多个实例？
RenJistroly 不能同时运行多个实例。如果收到此提示：
- 点击「退出」关闭旧实例
- 或用活动监视器强制退出 RenJistroly 进程

### Q: 如何在终端中启动应用？
```bash
open /Applications/RenJistroly.app
# 或从源码目录
swift run
```

## 使用问题

### Q: 快捷键 `Option + Space` 不起作用？
检查是否有其他应用占用了该快捷键（如一些输入法切换器）。
- 在设置中确认「启用浮动面板」已开启
- 确认应用有辅助功能权限

### Q: AI 回复不准确？
- 检查设置中默认模型已配置 API Key
- 尝试切换到 Claude（默认推荐）或其他模型
- 确保描述足够详细

### Q: 浮动面板如何切换到全窗口模式？
点击面板右上角菜单按钮（⋯），选择「显示模式」>「展开」或「沉浸」。

### Q: 如何新建对话？
点击面板右上角菜单按钮（⋯），选择「新建对话」。

### Q: 对话历史会保存吗？
会。对话保存在本地文件中，你可以在展开模式的左侧侧边栏搜索和浏览历史对话。在设置中也可以清除历史。

## 企业安全

### Q: 如何设置只读模式？
1. 打开设置 > 模式控制面板
2. 开启「只读」模式
3. 所有写操作将被自动拦截

### Q: 操作确认弹窗挡住了界面？
点击弹窗外的灰色半透明区域可以取消操作。

### Q: 如何查看操作审计日志？
在展开模式下，点击工具栏的 Agent Console 按钮（三个矩形图标），可以实时查看操作记录。

## 语音

### Q: 语音输入不工作？
1. 检查麦克风权限是否已授权
2. 检查浮动面板底部的语音状态：
   - 绿色 = 就绪
   - 蓝色 = 正在聆听
   - 红色 = 出错（查看错误信息）
3. 在设置中尝试切换语音语言

### Q: Gate 转发没反应？
1. 确认设置中「Gate 语音转发」已开启
2. 检查 Gate 目录路径是否正确
3. Gate 需要独立进程运行，确认 gate 服务已启动

### Q: 语音转写不准？
- 确保环境安静
- 在设置中确认选择了正确的语音语言
- 本地 OCR/ASR 引擎基于 ONNX 模型，精度依赖模型训练数据

## 构建与开发

### Q: 从源码构建失败？
```bash
# 确保 Xcode 和 Command Line Tools 版本正确
xcode-select -p
swift --version

# 清理后重试
swift package clean
swift build -c release
```

常见问题：
- ONNX Runtime 版本警告可以忽略（不影响运行）
- 确保 Xcode 版本支持 Swift 6.2

### Q: 如何只构建 MCP 服务器？
```bash
swift build --target RenJistrolyMCP -c release
```

### Q: 如何运行测试？
```bash
# 全量测试
swift test

# 指定模块
swift test --target RenJistrolyModelsTests

# 安全测试
swift test --target SecurityTests

# 基准测试
swift test --target PerformanceTests
```

### Q: 版本兼容性？
- 需要的系统就是 macOS 15+，Apple Silicon
- Swift 6.2+
- 不需要 Xcode（纯 SwiftPM，但也兼容 Xcode 项目）

## 问题反馈

如果能复现问题，请收集以下信息提交 GitHub Issue：

- 系统版本 (`sw_vers`)
- RenJistroly 版本（设置 > 关于）
- 复现步骤
- Console.app 中 RenJistroly 的日志
- 如果有崩溃，crash report 文件 (`~/Library/Logs/DiagnosticReports/`)
