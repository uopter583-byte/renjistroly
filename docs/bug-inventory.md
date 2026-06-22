
# RenJistroly 使用场景穷举 & 缺陷清单

## 使用场景分类（专业开发者 + AI 编程助手交互）

---

### A. 屏幕/上下文感知（80+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| A1 | "看到我屏幕上有啥" | OCR → 描述窗口/内容 | **BUG#1** 内部 LLM 说"看不到"，但 MCP screen_observe 正常 |
| A2 | "当前前台是什么 App" | 读 frontmostApp 返回 | 正常 |
| A3 | "终端里在跑什么命令" | OCR + 焦点控件读取 | **BUG#2** RenJistroly 浮窗遮挡终端时 OCR 抓的是浮窗自身文字 |
| A4 | "Xcode 当前打开的文件" | AX 读 Xcode 窗口标题+焦点 | **BUG#3** Xcode 的 AX 树较深，ui_tree depth=3 可能不够 |
| A5 | "VS Code 打开的文件夹路径" | 窗口标题解析 | 窗口标题可能被截断 |
| A6 | "Chrome 当前页面内容" | AppleScript 读页面 | **BUG#4** Chrome 需 JavaScript 权限，否则只读标题 |
| A7 | "Safari 标签页标题" | SafariDriver.currentPageState() | 正常 |
| A8 | "读一下这个错误信息" | OCR 截取错误弹窗 → 识别 | **BUG#5** 弹窗太小或半透明时 OCR 漏掉 |
| A9 | "选中那段代码，解释一下" | 读 selectedText → 给 LLM | 正常 |
| A10 | "当前有多少个窗口" | list_windows 返回 | 正常，但过滤不完整 |
| A11 | "Dock 上有哪些应用" | OCR 读 Dock | Dock 被 excludeDesktopElements 过滤 |
| A12 | "菜单栏上是什么时间" | OCR 读 menu bar | menu bar 在 OCR 范围但文字太小 |
| A13 | "通知中心有什么" | OCR 或 AX 读通知 | 通知中心的 AX 树通常不可访问 |
| A14 | "Finder 当前路径" | FinderDriver.currentWindowState() | 正常 |
| A15 | "终端当前工作目录" | AX 读窗口标题 | 可靠，但终端 title 可能被截断 |
| A16 | "读一下当前 git diff" | 终端 OCR + 选中文字 | 需要先选中 diff 输出 |
| A17 | "这个图/PDF 里有什么" | OCR 读预览窗口 | **BUG#6** Vision OCR 对代码/终端还行，对图片混合文字很差 |
| A18 | "模拟器当前画面" | OCR 读 iOS Simulator | Simulator 是 Metal 渲染，OCR 几乎无文字 |
| A19 | "系统设置里现在是什么" | AX 读设置面板 | 正常 |
| A20 | "活动监视器里 CPU 最高的是啥" | OCR 读活动监视器 | 动态刷新导致状态不一致 |
| A21 | "Xcode 构建进度条到哪了" | OCR 读构建状态栏 | 进度条不是文字，无法 OCR |
| A22 | "Docker Desktop 容器状态" | OCR 读 Docker | 正常 |
| A23 | "数据库 GUI 里的查询结果" | OCR 读 TablePlus/DataGrip | 表格文字密集，OCR 乱序 |
| A24 | "Figma 设计稿里的颜色值" | OCR 读 Figma | **BUG#7** 设计工具文字零散，OCR 难以结构化 |
| A25 | "Slack 最新消息" | OCR 读 Slack 窗口 | 正常 |
| A26 | "微信聊天记录" | AX 读 WeChat | AX 树部分可用 |
| A27 | "Notes 里记了什么" | OCR 或 AX | 正常 |
| A28 | "日历今天有什么安排" | AppleScript 读日历 | AppleScript 权限 |
| A29 | "邮件最新一封" | AppleScript 读 Mail | 可能受限 |
| A30 | "当前 Wi-Fi 名称" | shell: networksetup | 需要 shell 权限 |
| A31 | "电池电量" | shell: pmset -g batt | 需要 shell 权限 |
| A32 | "磁盘空间" | shell: df -h | 需要 shell 权限 |
| A33 | "外接显示器信息" | system_profiler | 正常 |
| A34 | "蓝牙设备列表" | system_profiler | 正常 |
| A35 | "剪贴板内容" | NSPasteboard.general | 正常 |
| A36 | "当前输入法" | AX 读输入源 | 部分可读 |
| A37 | "Spotlight 搜索结果" | OCR 读 Spotlight 弹窗 | Spotlight 窗口短暂，难捕获 |
| A38 | "Mission Control 界面" | OCR | **BUG#8** 动画中捕获结果不可靠 |
| A39 | "锁屏界面" | 无法捕获 | 安全限制 |
| A40 | "外接 Mac 的 Sidecar 屏幕" | 多显示器支持 | **BUG#9** 只捕获主显示器 |
| A41 | "这个 app 的 About 窗口" | OCR 读弹窗 | 正常 |
| A42 | "系统通知横幅" | OCR | 通知横幅 3 秒消失，不易捕获 |
| A43 | "读一下 Alfred/Raycast 的结果" | OCR | Alfred 窗口消失快 |
| A44 | "App Store 更新列表" | OCR | 正常 |
| A45 | "Music 正在播放什么" | AppleScript | 权限 |
| A46 | "读一下控制中心" | OCR | 控制中心短暂 |
| A47 | "系统语言和地区设置" | 设置面板 AX | 正常 |
| A48 | "默认浏览器" | shell: defaults read | shell 权限 |
| A49 | "已安装的 Homebrew 包" | shell: brew list | shell 权限 |
| A50 | "Node.js 版本" | shell: node -v | shell 权限 |

### B. 代码阅读/理解（100+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| B1 | "打开这个文件看看" | 在编辑器打开 → OCR / read | **BUG#10** 没有直接读文件内容的能力，必须通过 OCR 或终端 cat |
| B2 | "这个函数做了什么" | 定位函数 → 读代码 → LLM 解释 | 依赖 OCR 读编辑器，不可靠 |
| B3 | "这个类的继承关系" | LSP: goToDefinition → 分析 | 通过 MCP，但内部 LLM 无 LSP 能力 |
| B4 | "谁调用了这个方法" | LSP: findReferences | 同上 |
| B5 | "这行代码的 git blame" | git blame → 输出 | 需要 shell 执行 |
| B6 | "最近谁改了这个文件" | git log -- path | shell |
| B7 | "这个 import 从哪里来" | LSP: goToDefinition | 通过 MCP |
| B8 | "找出所有 TODO 注释" | grep TODO | shell |
| B9 | "这个 protocol 的实现在哪里" | LSP: goToImplementation | MCP |
| B10 | "翻到第 200 行" | 编辑器滚动 | **BUG#11** scroll 只支持方向+数量，不支持精确行号 |
| B11 | "选中这个函数完整代码" | AX: 选中范围 | **BUG#12** 无法跨多行精确选中范围 |
| B12 | "这个变量类型是什么" | LSP: hover | MCP |
| B13 | "这段正则是什么意思" | 读选中 → LLM 解释 | 正常 |
| B14 | "注释里说的 ISSUE-123 是什么" | OCR → LLM 解释 | OCR 读注释可能不完整 |
| B15 | "SwiftUI 这个 modifier 干嘛的" | 读选中 → LLM | 正常 |
| B16 | "UIKit 和 SwiftUI 版本对比" | 两个文件切换对比 | **BUG#13** 跨文件上下文切换不连贯 |
| B17 | "这个 CoreData 模型关系图" | 读 xcdatamodel | .xcdatamodel 是 XML，可读但不易理解 |
| B18 | "Info.plist 里有哪些权限" | 读 plist | 可 OCR 或 cat |
| B19 | "Package.swift 依赖版本" | 读文件 | OCR/cat |
| B20 | "项目里用了哪些第三方库" | Package.resolved / Podfile.lock | 读文件 |
| B21 | "这个 commit 改了啥" | git show | shell |
| B22 | "对比这两个版本的差异" | git diff A B | shell |
| B23 | "config 文件里的环境变量" | 读 .env / .xcconfig | **BUG#14** .env 文件可能被 .gitignore，打开时需要确认路径 |
| B24 | "CI 配置里有哪些 step" | 读 .github/workflows/*.yml | 读文件 |
| B25 | "Dockerfile 基础镜像" | 读 Dockerfile | 读文件 |
| B26 | "Makefile 有哪些 target" | 读 Makefile | 读文件 |
| B27 | "这个 shell 脚本做了什么" | 读脚本 → 解释 | OCR/cat |
| B28 | "fastlane 配置" | 读 Fastfile | OCR/cat |
| B29 | "Xcode 的 build settings" | xcodebuild -showBuildSettings | shell |
| B30 | "这个 scheme 的配置" | 读 .xcscheme | XML 可读 |
| B31 | "项目里多少个 Swift 文件" | find . -name '*.swift' | wc | shell |
| B32 | "最大的文件是哪个" | find + wc | shell |
| B33 | "代码总行数" | cloc / tokei | shell |
| B34 | "找出所有 force unwrap" | grep '!' *.swift | shell |
| B35 | "找出所有 print 语句" | grep 'print(' | shell |
| B36 | "找出所有 DispatchQueue.main.async" | grep | shell |
| B37 | "Swift Concurrency 检查" | swift build -Xswiftc -warn-concurrency | shell |
| B38 | "这个 enum 的所有 case" | 读代码 → 枚举 | OCR/LSP |
| B39 | "API 文档在哪里" | 项目结构 | 需要读文件 |
| B40 | "README 里的安装步骤" | 读 README.md | 读文件 |
| B41 | "CHANGELOG 最新版本变化" | 读 CHANGELOG.md | 读文件 |
| B42 | "这个 extension 扩展了哪个类" | 读代码 | OCR |
| B43 | "协议和实现的跳转关系" | LSP | MCP |
| B44 | "错误类型的继承链" | 读代码 + LSP | 组合操作 |
| B45 | "Keychain 使用方式" | 读代码 | OCR |
| B46 | "网络层的 URL 配置" | 读 NetworkService | OCR |
| B47 | "SwiftData model 定义" | 读 @Model class | OCR |
| B48 | "App 入口 @main 结构" | 读 App.swift | OCR |
| B49 | "target 配置" | 读 project.yml / pbxproj | 文件 |
| B50 | "单元测试覆盖率" | 读覆盖率报告 | 文件/shell |

### C. 代码编写/编辑（120+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| C1 | "在光标位置插入这个函数" | type_text 输入代码 | **BUG#15** type_text 不支持多行（会按回车提交）|
| C2 | "把选中代码替换为..." | 复制 → AX 输入换行 | **BUG#16** 替换大段代码很慢，逐字输入 |
| C3 | "在文件末尾添加 extension" | 滚动到底 → 输入 | 组合操作，步骤多易失败 |
| C4 | "重命名这个变量为 xxx" | LSP: rename | 通过 MCP |
| C5 | "选中整行并复制" | Cmd+Shift+→, Cmd+C | shortcut 组合 |
| C6 | "粘贴刚才的内容" | Cmd+V | shortcut |
| C7 | "撤销" | Cmd+Z | shortcut |
| C8 | "重做" | Cmd+Shift+Z | shortcut |
| C9 | "格式化代码" | Cmd+Opt+I (Xcode) | shortcut，依赖编辑器 |
| C10 | "缩进" | Tab | shortcut |
| C11 | "反缩进" | Shift+Tab | shortcut |
| C12 | "移动到行首/行尾" | Cmd+← / Cmd+→ | shortcut |
| C13 | "移动到文件头/尾" | Cmd+↑ / Cmd+↓ | shortcut |
| C14 | "选中下一个同名变量" | Cmd+D (多光标) | shortcut |
| C15 | "全局查找 xxx" | Cmd+Shift+F | shortcut |
| C16 | "在文件中查找" | Cmd+F | shortcut |
| C17 | "跳转到定义" | Cmd+Click / Ctrl+Cmd+J | shortcut |
| C18 | "打开快速打开面板" | Cmd+Shift+O (Xcode) | shortcut |
| C19 | "切换 .h/.m" | Cmd+Ctrl+↑ | shortcut |
| C20 | "折叠/展开代码块" | Opt+Cmd+← | shortcut |
| C21 | "生成 init" | Xcode: Editor → Generate | activate_menu |
| C22 | "添加文档注释" | Cmd+Opt+/ | shortcut |
| C23 | "注释/取消注释" | Cmd+/ | shortcut |
| C24 | "新建文件" | Cmd+N | shortcut |
| C25 | "保存" | Cmd+S | shortcut |
| C26 | "全部保存" | Opt+Cmd+S | shortcut |
| C27 | "切换 tab" | Cmd+Shift+] | shortcut |
| C28 | "关闭 tab" | Cmd+W | shortcut |
| C29 | "重新打开关闭的 tab" | Cmd+Shift+T | shortcut |
| C30 | "切换 scheme" | 鼠标点击 scheme 选择器 | **BUG#17** Xcode scheme 选择器不是标准 AX 控件 |
| C31 | "选择模拟器设备" | 点击设备选择器 | 同上 |
| C32 | "Clean Build Folder" | Cmd+Shift+K | shortcut |
| C33 | "Product → Archive" | activate_menu | 正常 |
| C34 | "Show/Hide Debug Area" | Cmd+Shift+Y | shortcut |
| C35 | "Show/Hide Navigator" | Cmd+0 | shortcut |
| C36 | "Show/Hide Inspector" | Cmd+Opt+0 | shortcut |
| C37 | "切换 Navigator tab" | Cmd+1~9 | shortcut |
| C38 | "打开 Assistant Editor" | Cmd+Opt+Return | shortcut |
| C39 | "关闭 Assistant Editor" | Cmd+Return | shortcut |
| C40 | "Move Focus to Editor" | Cmd+J | shortcut |
| C41 | "Focus Filter Bar" | Cmd+Opt+J | shortcut |
| C42 | "在 Xcode 中 Reveal in Project Navigator" | Cmd+Shift+J | shortcut |
| C43 | "打开 Organizer" | Cmd+Opt+Shift+O | shortcut |
| C44 | "打开 Devices and Simulators" | Cmd+Shift+2 | shortcut |
| C45 | "创建 SwiftUI preview" | 编辑器操作 | 依赖 Xcode |
| C46 | "添加 breakpoint" | Cmd+\ | shortcut |
| C47 | "禁用/启用 breakpoint" | Cmd+Y | shortcut |
| C48 | "Step Over" | F6 | shortcut |
| C49 | "Step Into" | F7 | shortcut |
| C50 | "Continue" | Cmd+Ctrl+Y | shortcut |
| C51 | "LLDB: po 变量" | 在 Debug Console 输入 | type_text |
| C52 | "复制 Debug Console 输出" | Cmd+A, Cmd+C | shortcut |
| C53 | "切换到 VS Code" | Cmd+Tab | shortcut |
| C54 | "VS Code 打开命令面板" | Cmd+Shift+P | shortcut |
| C55 | "VS Code 打开终端" | Ctrl+` | shortcut |
| C56 | "VS Code 切换侧边栏" | Cmd+B | shortcut |
| C57 | "VS Code 搜索文件" | Cmd+P | shortcut |
| C58 | "VS Code Zen Mode" | Cmd+K Z | shortcut |
| C59 | "VS Code 格式化文档" | Shift+Opt+F | shortcut |
| C60 | "终端新建 tab" | Cmd+T | shortcut |
| C61 | "终端新建窗口" | Cmd+N | shortcut |
| C62 | "终端清屏" | Cmd+K | shortcut |
| C63 | "终端切换 tab" | Cmd+Shift+[ | shortcut |
| C64 | "终端 kill 当前进程" | Ctrl+C | shortcut |
| C65 | "终端暂停进程" | Ctrl+Z | shortcut |
| C66 | "终端上翻历史" | Ctrl+P / ↑ | shortcut |
| C67 | "终端搜索历史" | Ctrl+R | shortcut |
| C68 | "在光标处插入代码片段" | 粘贴 | **BUG#18** 粘贴大段代码可能被 type_text 逐字符输入导致极慢 |
| C69 | "替换选中文本" | 删+粘贴 | 需要组合操作 |
| C70 | "多光标编辑" | 不支持 | **BUG#19** AX 不支持多光标位置 |

### D. 构建/测试/调试（100+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| D1 | "编译一下" | swift build / xcodebuild | shell |
| D2 | "编译有错误吗" | 读错误输出 → 分析 | **BUG#20** shell 输出过长时截断，漏掉关键错误 |
| D3 | "这个编译错误是什么意思" | OCR → LLM 解释 | 需要先选中错误 |
| D4 | "帮我修这个编译错误" | 读错误 → 修改代码 → 重编译 | 多步循环，需 MM 确认 |
| D5 | "运行测试" | swift test / xcodebuild test | shell |
| D6 | "哪个测试挂了" | 解析测试输出 | **BUG#21** 没有结构化解析测试输出 |
| D7 | "只跑这个测试文件" | swift test --filter | shell |
| D8 | "跑全部单元测试" | swift test | shell |
| D9 | "跑 UI 测试" | xcodebuild test -only-testing | shell |
| D10 | "测试覆盖率" | xcodebuild test -enableCodeCoverage | shell |
| D11 | "看看覆盖率报告" | 打开 .xcresult | open |
| D12 | "打开最新 .xcresult" | find + open | 组合命令 |
| D13 | "运行 App" | xcodebuild / 点击 Run | shell / shortcut |
| D14 | "在模拟器上跑" | xcodebuild -destination | shell |
| D15 | "在真机上跑" | xcodebuild -destination | shell |
| D16 | "切换构建配置 Debug/Release" | xcodebuild -configuration | shell |
| D17 | "增量编译还是全量编译" | 看 xcodebuild 输出 | OCR |
| D18 | "编译耗时分析" | swift-build --show-detailed-timing | shell |
| D19 | "为什么编译慢" | 读 timing 报告 → 分析 | 需要解析 |
| D20 | "查看编译警告" | 读 xcodebuild 输出 | OCR |
| D21 | "忽略这个警告" | 改代码加 suppress | 编辑操作 |
| D22 | "swiftlint 检查" | swiftlint lint | shell |
| D23 | "swiftformat 格式化" | swiftformat . | shell |
| D24 | "ESLint 检查" | npx eslint | shell |
| D25 | "Prettier 格式化" | npx prettier --write | shell |
| D26 | "Code Review" | 读 diff → 审查 | OCR + LLM |
| D27 | "看 PR changes" | gh pr diff | shell |
| D28 | "PR 的 CI 过了吗" | gh pr checks | shell |
| D29 | "App 启动耗时" | Instruments Time Profiler | **BUG#22** Instruments 需要 GUI 操作，自动化困难 |
| D30 | "内存泄漏检查" | xcodebuild test -enablePerformanceTests | shell |
| D31 | "查看崩溃日志" | 打开 Console.app → 读 | OCR |
| D32 | "符号化崩溃堆栈" | atos / symbolicatecrash | shell |
| D33 | "模拟低内存" | simctl status_bar override | shell |
| D34 | "网络请求抓包" | Charles / Proxyman | **BUG#23** 需手动启动代理工具 |
| D35 | "CoreData 迁移测试" | 跑 App + 验证 | 多步操作 |
| D36 | "检查 entitlements" | codesign -d --entitlements | shell |
| D37 | "签名验证" | codesign -vvv | shell |
| D38 | "公证检查" | spctl -a | shell |
| D39 | "Archiving" | xcodebuild archive | shell |
| D40 | "Export IPA" | xcodebuild -exportArchive | shell |
| D41 | "上传 TestFlight" | xcrun altool | shell |
| D42 | "检查 provisioning profile" | security cms -D | shell |
| D43 | "Xcode DerivedData 路径" | 默认路径 | shell |
| D44 | "清理 DerivedData" | rm -rf ~/Library/Developer/Xcode/DerivedData | **BUG#24** 高风险操作，需用户确认 |
| D45 | "重置模拟器" | xcrun simctl erase all | 高风险 |
| D46 | "查看模拟器列表" | xcrun simctl list | shell |
| D47 | "启动特定模拟器" | xcrun simctl boot | shell |
| D48 | "模拟器截图" | xcrun simctl io booted screenshot | shell |
| D49 | "模拟器录屏" | xcrun simctl io booted recordVideo | shell |
| D50 | "模拟器推文件" | xcrun simctl addmedia | shell |

### E. Git 操作（80+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| E1 | "git status" | 读工作区状态 | shell |
| E2 | "git diff" | 读未暂存变更 | shell |
| E3 | "git diff --staged" | 读已暂存变更 | shell |
| E4 | "add 这个文件" | git add path | shell |
| E5 | "add 全部" | git add -A | shell（高风险）|
| E6 | "commit" | git commit -m | shell |
| E7 | "commit 并详细描述" | git commit （打开编辑器）| **BUG#25** 交互式编辑器无法通过 type_text 完成 |
| E8 | "push" | git push | shell |
| E9 | "force push ？" | git push --force | **BUG#26** force push 需二次确认，当前无 |
| E10 | "pull" | git pull | shell |
| E11 | "fetch" | git fetch | shell |
| E12 | "merge main" | git merge main | shell |
| E13 | "rebase onto main" | git rebase main | shell |
| E14 | "解决冲突" | 编辑器显示冲突标记 → 选择 | **BUG#27** 冲突解决需手动编辑，不能仅靠 LLM |
| E15 | "abort merge" | git merge --abort | shell |
| E16 | "abort rebase" | git rebase --abort | shell |
| E17 | "cherry-pick 这个 commit" | git cherry-pick | shell |
| E18 | "stash" | git stash | shell |
| E19 | "stash pop" | git stash pop | shell |
| E20 | "stash list" | git stash list | shell |
| E21 | "查看所有分支" | git branch -a | shell |
| E22 | "创建分支" | git checkout -b | shell |
| E23 | "切换分支" | git switch / checkout | shell |
| E24 | "删除分支" | git branch -d | shell |
| E25 | "查看日志" | git log --oneline | shell |
| E26 | "查看 reflog" | git reflog | shell |
| E27 | "reset 到上个 commit" | git reset HEAD~1 | **BUG#28** reset 高风险，缺少 Gate 确认 |
| E28 | "reset --hard" | git reset --hard | 极高风险 |
| E29 | "查看某个 commit 的详情" | git show | shell |
| E30 | "这个改动是什么时候引入的" | git bisect / git log -S | shell |
| E31 | "对比两个分支" | git diff branch1..branch2 | shell |
| E32 | "当前分支落后 main 多少" | git rev-list --count | shell |
| E33 | "远程地址" | git remote -v | shell |
| E34 | "添加 remote" | git remote add | shell |
| E35 | "修改 remote URL" | git remote set-url | shell |
| E36 | "tag 当前 commit" | git tag -a | shell |
| E37 | "push tag" | git push --tags | shell |
| E38 | "删除远程 tag" | git push --delete origin tag | shell |
| E39 | "创建 PR" | gh pr create | shell |
| E40 | "查看 PR" | gh pr view | shell |
| E41 | "列出 PR" | gh pr list | shell |
| E42 | "checkout PR" | gh pr checkout | shell |
| E43 | "review PR" | gh pr review | shell |
| E44 | "merge PR" | gh pr merge | shell |
| E45 | "查看 issue" | gh issue view | shell |
| E46 | "创建 issue" | gh issue create | shell |
| E47 | "squash 最近 3 个 commit" | git rebase -i HEAD~3 | **BUG#29** 交互式 rebase 无法自动化 |
| E48 | "amend 上一个 commit" | git commit --amend | shell |
| E49 | "查看 .gitignore" | cat .gitignore | shell / read |
| E50 | "git hooks 列表" | ls .git/hooks | shell |

### F. 终端/Shell 操作（80+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| F1 | "跑这个命令" | shell 执行 | **BUG#30** 命令执行无超时保护，长命令可能卡死 |
| F2 | "后台跑" | nohup / & | shell |
| F3 | "看进程输出" | 读终端 | OCR |
| F4 | "kill 这个进程" | kill PID | shell |
| F5 | "强制 kill" | kill -9 | 高风险 |
| F6 | "列出端口占用" | lsof -i :端口号 | shell |
| F7 | "netstat" | netstat -an | shell |
| F8 | "ping google.com" | ping -c 4 | shell |
| F9 | "curl 这个 API" | curl | shell |
| F10 | "下载文件" | curl -O / wget | shell |
| F11 | "解压 zip" | unzip | shell |
| F12 | "解压 tar.gz" | tar -xzf | shell |
| F13 | "查找文件" | find . -name '*.swift' | shell |
| F14 | "grep 搜索" | grep -r 'pattern' . | shell |
| F15 | "rg 搜索（更快）" | rg 'pattern' | shell |
| F16 | "用 sed 批量替换" | sed -i 's/a/b/g' | **BUG#31** sed -i 不可逆，缺安全确认 |
| F17 | "用 awk 处理文本" | awk '{print $1}' | shell |
| F18 | "jq 解析 JSON" | jq '.key' | shell |
| F19 | "sort / uniq / wc" | 管道组合 | shell |
| F20 | "查看文件前/后 N 行" | head -N / tail -N | shell |
| F21 | "监听文件变化" | tail -f | **BUG#32** tail -f 是持续进程，不适合一次性 shell |
| F22 | "watch 命令" | watch -n 1 'cmd' | 持续进程 |
| F23 | "安装 brew 包" | brew install | shell |
| F24 | "更新 brew" | brew update && brew upgrade | shell |
| F25 | "npm install" | npm install | shell |
| F26 | "npm run dev" | 启动 dev server | **BUG#33** dev server 是持续进程，不易管理 |
| F27 | "pod install" | pod install | shell |
| F28 | "bundle install" | bundle install | shell |
| F29 | "pip install" | pip install | shell |
| F30 | "docker compose up" | docker compose up | 持续进程 |
| F31 | "docker ps" | docker ps | shell |
| F32 | "docker logs" | docker logs container | shell |
| F33 | "docker exec" | docker exec -it container sh | 交互式 |
| F34 | "创建目录" | mkdir -p | shell |
| F35 | "复制文件" | cp / mv | shell |
| F36 | "删除文件" | rm | **BUG#34** rm 高风险，无回收站保护 |
| F37 | "chmod" | chmod +x | shell |
| F38 | "创建符号链接" | ln -s | shell |
| F39 | "压缩文件" | tar -czf | shell |
| F40 | "查看文件大小" | du -sh / ls -la | shell |
| F41 | "查找大文件" | du -sh * | sort | shell |
| F42 | "环境变量" | export FOO=bar | shell |
| F43 | "查看环境变量" | env / echo $FOO | shell |
| F44 | "source 文件" | source .env | shell |
| F45 | "which 命令路径" | which swift | shell |
| F46 | "命令帮助" | man / cmd --help | shell |
| F47 | "sudo 操作" | sudo ... | **BUG#35** sudo 需要密码，无法自动化 |
| F48 | "钥匙串访问" | security find-generic-password | shell（需授权）|
| F49 | "Fastlane 部署" | fastlane beta | shell |
| F50 | "Python 脚本" | python3 script.py | shell |

### G. 浏览器/Documentation（60+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| G1 | "打开 Apple 文档" | open_url | 正常 |
| G2 | "搜索 Stack Overflow" | safari_search / open_url | 正常 |
| G3 | "打开 GitHub 仓库" | open_url | 正常 |
| G4 | "查这个 API 文档" | 打开 → OCR 读页面 | **BUG#36** 网页 OCR 量大，只读了首屏 |
| G5 | "看 release notes" | 打开页面 → 读 | OCR |
| G6 | "搜索 npm 包" | open_url | 正常 |
| G7 | "查 CocoaPods 版本" | open_url | 正常 |
| G8 | "MDN 文档" | open_url → OCR | OCR |
| G9 | "翻到页面中部" | scroll down | 正常 |
| G10 | "点击链接" | ui_click label | **BUG#37** 网页上 link label 可能不是可见文字 |
| G11 | "填入搜索词" | type_text | 正常 |
| G12 | "回车搜索" | ui_shortcut Enter | 正常 |
| G13 | "后退" | Cmd+[ | shortcut |
| G14 | "前进" | Cmd+] | shortcut |
| G15 | "刷新" | Cmd+R | shortcut |
| G16 | "打开新标签" | Cmd+T | shortcut |
| G17 | "关闭标签" | Cmd+W | shortcut |
| G18 | "切换标签" | Cmd+Shift+[ | shortcut |
| G19 | "打开开发者工具" | Cmd+Opt+I | shortcut |
| G20 | "查看页面源码" | Cmd+Opt+U | shortcut |
| G21 | "复制 URL" | Cmd+L, Cmd+C | shortcut 组合 |
| G22 | "粘贴并前往" | Cmd+L, Cmd+V, Enter | 组合 |
| G23 | "DevDocs 搜索" | open_url + 输入 | 组合 |
| G24 | "Hacker News" | open_url | 正常 |
| G25 | "Reddit r/swift" | open_url | 正常 |
| G26 | "Swift Forums" | open_url | 正常 |
| G27 | "中文文档（SwiftGG）" | open_url | 正常 |
| G28 | "Objective-C 文档" | open_url | 正常 |
| G29 | "Swift Evolution proposals" | open_url + 搜索 | 组合 |
| G30 | "WWDC session 笔记" | open_url | 正常 |

### H. Xcode 集成（50+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| H1 | "在 Xcode 里打开这个文件" | Cmd+Shift+O + 输入文件名 + Enter | **BUG#38** 快速打开面板是临时窗口，难以精确输入 |
| H2 | "Xcode 里展示 Project Navigator" | Cmd+0 | shortcut |
| H3 | "在 Project Navigator 里定位当前文件" | Cmd+Shift+J | shortcut |
| H4 | "Add files to project" | Cmd+Opt+A | shortcut |
| H5 | "New Group" | Cmd+Opt+N | shortcut |
| H6 | "Show Code Review" | Cmd+Opt+Shift+Return | shortcut |
| H7 | "Show blame" | 菜单操作 | activate_menu |
| H8 | "Show version editor" | Cmd+Opt+Shift+Return | shortcut |
| H9 | "Open in new tab" | Opt+双击 | click_at |
| H10 | "调整编辑器分割" | 拖拽分界线 | drag |
| H11 | "Xcode Previews 刷新" | Cmd+Opt+P | shortcut |
| H12 | "Pin preview" | 点击 pin 按钮 | click_at |
| H13 | "看 View debug" | Debug → View Debugging | activate_menu |
| H14 | "Memory Graph" | Debug → Memory Graph | activate_menu |
| H15 | "Instruments 启动" | Product → Profile | shortcut Cmd+I |
| H16 | "Xcode 偏好设置" | Cmd+, | shortcut |
| H17 | "Accounts 设置" | Xcode → Settings → Accounts | activate_menu |
| H18 | "Manage Certificates" | 点击 Manage Certificates | ui_click |
| H19 | "断点导航" | Cmd+8 | shortcut |
| H20 | "报告导航" | Cmd+9 | shortcut |
| H21 | "Debug Navigator" | Cmd+7 | shortcut |
| H22 | "Test Navigator" | Cmd+6 | shortcut |
| H23 | "Issue Navigator" | Cmd+5 | shortcut |
| H24 | "Find Navigator" | Cmd+3 | shortcut |
| H25 | "Symbol Navigator" | Cmd+2 | shortcut |
| H26 | "源码编辑器回到标准布局" | Cmd+Return | shortcut |
| H27 | "Canvas 显示/隐藏" | Cmd+Opt+Return | shortcut |
| H28 | "Library" | Cmd+Shift+L | shortcut |
| H29 | "Code Snippets Library" | Cmd+Shift+L → tab | 组合 |
| H30 | "Font & Color 调整" | 菜单 | activate_menu |

### I. 语音交互（50+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| I1 | "听写中文" | 语音 → 转写中文 | 正常 |
| I2 | "听写英文" | 语音 → 转写英文 | **BUG#39** 语言混说时识别率下降 |
| I3 | "代码术语听写" | "UIView" / "deinit" 等 | **BUG#40** 代码术语常被错误转写 |
| I4 | "长段语音（>30 秒）" | 持续听写 | **BUG#41** 长录音无分段，超时可能丢文字 |
| I5 | "安静环境" | 正常 | 正常 |
| I6 | "嘈杂环境" | 降噪 → 识别 | **BUG#42** 无噪音抑制 |
| I7 | "中英文混合" | 混说识别 | 准确率低 |
| I8 | "数字和符号" | "第 123 行" | 数字转写可接受 |
| I9 | "文件名和路径" | "/Users/yoming/Documents" | 路径转写常有错误 |
| I10 | "连续对话模式" | 问 → 答 → 再问 | **BUG#43** 自动重启监听有时不触发 |
| I11 | "打断助手回复" | 语音打断 | **BUG#44** 没有打断机制，必须等说完 |
| I12 | "暂停对话" | "暂停" | **BUG#45** 没有语音唤醒词/暂停词 |
| I13 | "语音纠错" | "不对，我说的是..." | 需重新说 |
| I14 | "快速确认" | "嗯"/"好"/"对" | **BUG#46** 未识别短确认词 |
| I15 | "取消操作" | "取消"/"算了" | 未处理 |
| I16 | "TTS 朗读回答" | 正常 | 正常 |
| I17 | "调语速" | "说慢点"/"说快点" | **BUG#47** 没有语音调速命令 |
| I18 | "停止朗读" | "别说了"/"停" | **BUG#48** 语音只能停止录音，不能停止朗读 |
| I19 | "重新读一遍" | 重新 TTS | 未实现 |
| I20 | "重复我刚才说的" | 复读语音转写 | 未实现 |

### J. 多工具协作 / 工作流（60+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| J1 | Xcode → 终端 → 浏览器 三窗口切换 | 流畅切换 | **BUG#49** 切换 app 后窗口焦点可能丢失 |
| J2 | "在 Xcode 改代码 → 终端编译 → 浏览器看文档" | 连续工作流 | 每一步需独立描述 |
| J3 | "同时开两个终端窗口" | 识别窗口标题区分 | 同标题终端难以区分 |
| J4 | "在 VS Code 和 Xcode 间切换" | 流畅 | 正常 |
| J5 | "终端跑测试时在浏览器查文档" | 多任务 | 需要多步操作 |
| J6 | "编译等待时切到 Slack 回消息" | 多任务切换 | 组合操作 |
| J7 | "把终端输出粘贴到 PR description" | 复制终端 → 粘贴浏览器 | 组合操作 |
| J8 | "从 GitHub Issues 复制文字到代码" | 浏览器 → Xcode | 组合操作 |
| J9 | "看微信消息 → 回复 → 回到代码" | 微信 + Xcode | 跨 App 操作 |
| J10 | "打开多个 Finder 窗口" | Finder 多窗口 | 正常 |
| J11 | "从 Finder 拖文件到 Xcode" | drag 操作 | **BUG#50** drag 坐标计算可能不准 |
| J12 | "截图 → 标注 → 粘贴到 PR" | 截图 + 标注工具 | 复杂工作流 |
| J13 | "运行脚本 → 看日志 → 找错误 → 修复" | 多步循环 | 需多次交互 |
| J14 | "新建分支 → 提交 → push → 创建 PR" | 一条龙 | 组合 git 命令 |
| J15 | "查看 CI 失败日志 → 找到原因 → 修改 → 推送" | 完整 CI 循环 | 多步操作 |
| J16 | "数据库迁移" | 跑 migration → 验证 | shell 组合 |
| J17 | "部署到 staging → 跑 smoke test → 看日志" | 部署流程 | shell + OCR |
| J18 | "Code Review: 读 diff → 评论 → approve" | gh pr review | shell |
| J19 | "从 Figma 切图 → 导入 Xcode Assets" | 设计 → 开发 | 多步操作 |
| J20 | "API 测试 (curl → 看响应 → 改代码)" | 开发循环 | shell + OCR + 编辑 |

### K. Gate 模式（外部 AI 中继）（40+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| K1 | "语音 → Gate → Claude Code 处理" | 语音转发 → 外部处理 → 回复朗读 | **BUG#51** Gate 无人在另一端监听时卡住 |
| K2 | "Gate → Claude Code / Codex / Hermes" | 多后端路由 | **BUG#52** Gate 模式不支持路由选择 |
| K3 | "Gate 模式下看屏幕" | 语音问 → Gate → Claude Code → screen_observe | 需要 Claude Code 主动调用工具 |
| K4 | "Gate 回复延迟过长" | 快速回复 | **BUG#53** Gate reply loop 每 500ms 轮询 |
| K5 | "Gate 缓冲区溢出" | 积压多条语音 | **BUG#54** speech_in.txt 单向追加，无清理 |
| K6 | "Gate 模式下切换回本地回复" | 语音控制切换 | **BUG#55** 无法语音切换 Gate 开关 |
| K7 | "Gate 断线重连" | 自动重连 | **BUG#56** Gate 是文件轮询，无重连机制 |
| K8 | "Gate 回复写入失败" | 错误提示 | **BUG#57** 写入失败无用户提示 |
| K9 | "多条语音连续发送" | 排队处理 | **BUG#58** 无队列，后一条覆盖前一条 |
| K10 | "Gate mode tool calling" | Claude Code 调 MCP 工具 → 结果回复 | **BUG#59** Gate 模式下工具结果无法返回 App |

### L. 权限/安全（30+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| L1 | "辅助功能权限未授权" | 提示授权 | 正常 |
| L2 | "屏幕录制权限未授权" | 提示授权 | 正常 |
| L3 | "麦克风权限未授权" | 提示授权 | 正常 |
| L4 | "语音识别权限未授权" | 提示授权 | 正常 |
| L5 | "Apple Events 权限未授权" | 提示授权 | 正常 |
| L6 | "首次启动权限引导" | 逐步引导用户授权 | **BUG#60** 权限引导流程不够直观 |
| L7 | "权限被撤销后" | 检测并重新提示 | **BUG#61** 运行时权限撤销未实时检测 |
| L8 | "rm -rf / 拒绝" | 安全策略拦截 | **BUG#62** 安全策略只检查关键词，可绕过 |
| L9 | "curl 敏感 URL" | 需要确认 | 未实现 |
| L10 | "git push --force main" | 阻止并警告 | **BUG#63** 未对 force push main 特殊处理 |
| L11 | "泄露 API key" | 检测并警告 | 未实现 |
| L12 | "sudo 操作" | Gate 确认 | 需确认 |
| L13 | "删除 Xcode 工程文件" | 警告 | 未实现 |
| L14 | "修改系统文件" | Gate 确认 + 警告 | 未实现 |
| L15 | "Keychain 密码访问" | Gate 确认 | 需确认 |

### M. 稳定性/性能（30+ 场景）

| # | 场景 | 期望行为 | 当前缺陷 |
|---|------|---------|---------|
| M1 | "长时间运行不崩溃" | 稳定 24h+ | **BUG#64** 内存缓慢增长（Voice + OCR CGImage）|
| M2 | "快速连续语音输入" | 无丢帧 | **BUG#65** 连续语音可能有竞态 |
| M3 | "OCR 高频调用" | 不卡死 | **BUG#66** OCR 是同步 Vision API，高频调用队列堆积 |
| M4 | "大屏（5K 显示器）OCR" | 正常识别 | **BUG#67** 5K 屏幕 OCR 图片 14MB+，耗时 > 2s |
| M5 | "两个 RenJistroly 实例" | 检测并阻止 | **BUG#68** 无实例互斥检测 |
| M6 | "Gate 文件被外部删除" | 重建 | **BUG#69** Gate 文件删除后无自动重建 |
| M7 | "磁盘空间不足时写 Gate" | 提示空间不足 | 未处理 |
| M8 | "App nap 导致响应延迟" | 后台仍响应 | **BUG#70** 后台时 App nap 可能暂停处理 |
| M9 | "睡眠唤醒后状态" | 恢复 | **BUG#71** 睡眠唤醒后 AX 连接可能断开 |
| M10 | "Swift 6 严格并发检查" | 通过编译 | **BUG#72** AssistantSessionController 有 @MainActor 和非隔离混用 |

---

## Bug 清单（Todo）

| ID | 严重度 | 类别 | 标题 | 状态 |
|----|--------|------|------|------|
| BUG#1 | P0 | 屏幕 | 内部 LLM 说"看不到屏幕"，但 MCP screen_observe 正常 | ✅ 已修 |
| BUG#2 | P1 | 屏幕 | RenJistroly 浮窗遮挡终端时 OCR 抓的是浮窗自身文字 | ✅ 已修 |
| BUG#3 | P2 | 屏幕 | Xcode AX 树较深，ui_tree depth=3 可能不够 | ✅ 已修（默认 depth 3→5）|
| BUG#4 | P2 | 浏览器 | Chrome 需 JavaScript 权限才能读页面内容 | ⬜ |
| BUG#5 | P2 | 屏幕 | 弹窗太小或半透明时 Vision OCR 漏掉文字 | ⬜ |
| BUG#6 | P2 | 屏幕 | Vision OCR 对图片混合文字识别很差 | ⬜ |
| BUG#7 | P2 | 屏幕 | 设计工具（Figma）文字零散，OCR 难以结构化 | ⬜ |
| BUG#8 | P2 | 屏幕 | Mission Control 动画中捕获结果不可靠 | ⬜ |
| BUG#9 | P2 | 屏幕 | 只捕获主显示器，外接显示器不支持 | ✅ 已修（捕获所有显示器并合并 OCR）|
| BUG#10 | P1 | 代码 | 没有直接读文件内容的能力，必须通过 OCR 或终端 cat | ⬜ |
| BUG#11 | P2 | UI | scroll 只支持方向+数量，不支持精确行号 | ⬜ |
| BUG#12 | P2 | UI | 无法跨多行精确选中代码范围 | ⬜ |
| BUG#13 | P2 | 上下文 | 跨文件上下文切换不连贯 | ⬜ |
| BUG#14 | P3 | 文件 | .env 文件被 .gitignore 时打开需要确认路径 | ⬜ |
| BUG#15 | P1 | 编辑 | type_text 不支持多行（会按回车提交）| ✅ 非Bug（用 Cmd+V 粘贴）|
| BUG#16 | P1 | 编辑 | 替换大段代码极慢（逐字符输入）| ✅ 已修（MCP 粘贴路径也恢复剪贴板）|
| BUG#17 | P2 | Xcode | Xcode scheme/设备选择器不是标准 AX 控件 | ⬜ |
| BUG#18 | P1 | 编辑 | 粘贴大段代码可能被 type_text 逐字符处理 | ✅ 已修 |
| BUG#19 | P3 | 编辑 | AX 不支持多光标位置 | ⬜ |
| BUG#20 | P1 | 终端 | shell 输出过长时截断，漏掉关键错误 | ⬜ |
| BUG#21 | P2 | 测试 | 没有结构化解析测试输出 | ⬜ |
| BUG#22 | P2 | 调试 | Instruments 需要 GUI 操作，自动化困难 | ⬜ |
| BUG#23 | P3 | 调试 | 代理工具(Charles/Proxyman)需手动启动 | ⬜ |
| BUG#24 | P1 | 安全 | rm -rf DerivedData 等高风险操作需用户确认 | ✅ 已修（rm 不在白名单，find -delete 等已拦截）|
| BUG#25 | P2 | Git | 交互式 git commit（编辑器）无法通过 type_text 完成 | ⬜ |
| BUG#26 | P1 | 安全 | git push --force 需二次确认，当前无 | ✅ 已修（force push 已识别为 shellWrite/high）|
| BUG#27 | P2 | Git | 冲突解决需手动编辑，不能仅靠 LLM | ⬜ |
| BUG#28 | P1 | 安全 | git reset 高风险，缺少 Gate 确认 | ✅ 已修（git reset 已识别为 shellWrite/high）|
| BUG#29 | P2 | Git | 交互式 rebase 无法自动化 | ⬜ |
| BUG#30 | P1 | 终端 | 命令执行无超时保护，长命令可能卡死 | ✅ 已有（30s timeout）|
| BUG#31 | P1 | 安全 | sed -i 不可逆，缺安全确认 | ✅ 已修（sed -i 已正确识别为 mutating）|
| BUG#32 | P2 | 终端 | tail -f 是持续进程，不适合一次性 shell | ⬜ |
| BUG#33 | P2 | 终端 | dev server 等持续进程不易管理 | ⬜ |
| BUG#34 | P1 | 安全 | rm 高风险，无回收站保护 | ✅ 已修（rm 不在命令白名单，find -delete/exec rm 已拦截）|
| BUG#35 | P2 | 权限 | sudo 需要密码，无法自动化 | ⬜ |
| BUG#36 | P2 | 浏览器 | 网页 OCR 量大，只读了首屏 | ⬜ |
| BUG#37 | P2 | 浏览器 | 网页上 link label 可能不是可见文字 | ⬜ |
| BUG#38 | P2 | Xcode | 快速打开面板是临时窗口，难以精确输入 | ⬜ |
| BUG#39 | P2 | 语音 | 语言混说时识别率下降 | ⬜ |
| BUG#40 | P2 | 语音 | 代码术语("UIView"/"deinit")常被错误转写 | ⬜ |
| BUG#41 | P2 | 语音 | 长录音无分段，超时可能丢文字 | ⬜ |
| BUG#42 | P3 | 语音 | 无噪音抑制 | ⬜ |
| BUG#43 | P1 | 语音 | 连续对话自动重启监听有时不触发 | ✅ 已修 |
| BUG#44 | P2 | 语音 | 没有打断 TTS 朗读的机制 | ✅ 已修（开始说话时自动停止朗读）|
| BUG#45 | P2 | 语音 | 没有语音唤醒词/暂停词 | ⬜ |
| BUG#46 | P3 | 语音 | 未识别短确认词("嗯"/"好") | ⬜ |
| BUG#47 | P3 | 语音 | 没有语音调速命令 | ⬜ |
| BUG#48 | P2 | 语音 | 语音只能停止录音，不能停止朗读 | ✅ 已修（stopListening 同时停止 TTS）|
| BUG#49 | P2 | 窗口 | 切换 app 后窗口焦点可能丢失 | ⬜ |
| BUG#50 | P2 | UI | drag 操作坐标计算可能不准 | ⬜ |
| BUG#51 | P0 | Gate | Gate 无人在另一端监听时卡住（"已通过 Gate 转发..."）| ✅ 已修 |
| BUG#52 | P2 | Gate | Gate 模式不支持多后端路由选择 | ⬜ |
| BUG#53 | P2 | Gate | Gate reply loop 每 500ms 轮询，延迟长 | ✅ 已修（500ms→150ms）|
| BUG#54 | P2 | Gate | speech_in.txt 单向追加，无清理机制 | ✅ 已修（超过 100KB 时自动截断重写）|
| BUG#55 | P2 | Gate | 无法语音切换 Gate 开关 | ✅ 已修（"开启转发"/"关闭转发" 语音指令）|
| BUG#56 | P2 | Gate | Gate 是文件轮询，无断线重连机制 | ⬜ |
| BUG#57 | P2 | Gate | Gate 写入失败无用户提示 | ⬜ |
| BUG#58 | P2 | Gate | 多条语音无队列，后一条可能覆盖 | ⬜ |
| BUG#59 | P1 | Gate | Gate 模式下工具调用结果无法返回 App | ⬜ |
| BUG#60 | P2 | 权限 | 首次权限引导流程不够直观 | ⬜ |
| BUG#61 | P2 | 权限 | 运行时权限撤销未实时检测 | ⬜ |
| BUG#62 | P1 | 安全 | 安全策略只检查关键词，可绕过 | ✅ 已修（ShellExecutor 加 shell 注入检测；isMutating 加 ``, $(), \|sh 检测）|
| BUG#63 | P1 | 安全 | 未对 force push main 特殊处理 | ✅ 已修（git push -f main/master 专门检测）|
| BUG#64 | P1 | 稳定性 | 内存缓慢增长（Voice + OCR CGImage）| ✅ 已排查（CGImage 未保留，observation 替换式赋值，无明显泄漏点）|
| BUG#65 | P2 | 稳定性 | 连续语音可能有竞态条件 | ⬜ |
| BUG#66 | P2 | 性能 | OCR 是同步 Vision API，高频调用队列堆积 | ✅ 已修（actor + isCapturing 防重入）|
| BUG#67 | P2 | 性能 | 5K 大屏 OCR 图片太大，耗时 > 2s | ✅ 已修（OCR 前缩小到 max 2560px）|
| BUG#68 | P2 | 稳定性 | 无实例互斥检测（多开冲突）| ✅ 已修 |
| BUG#69 | P3 | 可靠性 | Gate 文件被外部删除后无自动重建 | ✅ 已修（reply loop 自动重建目录）|
| BUG#70 | P2 | 可靠性 | App nap 可能暂停后台处理 | ✅ 已修（beginActivity 禁用 App Nap）|
| BUG#71 | P2 | 可靠性 | 睡眠唤醒后 AX 连接可能断开 | ✅ 已修（监听 didWakeNotification 重查权限）|
| BUG#72 | P2 | 架构 | @MainActor 和非隔离混用，潜在 data race | ⬜ |
