import Foundation

public struct AppInstructionLibrary: Sendable {
    public init() {}

    public func instructions(for appName: String?) -> String? {
        guard let appName else { return nil }
        let key = appName.lowercased()
        if key.contains("music") || appName.contains("音乐") {
            return "Music：搜索时先聚焦侧边栏 Search；播放曲目优先双击；加入队列需使用 More 菜单。"
        }
        if key.contains("clock") || appName.contains("时钟") {
            return "Clock：操作计时器/闹钟前先确认当前状态；已有计时器运行时不要直接覆盖。"
        }
        if key.contains("numbers") {
            return "Numbers：编辑单元格用点击选择；替换已有内容用多次点击；批量输入一行可用 tab 分隔。"
        }
        if key.contains("notion") {
            return "Notion：文档由 block 组成；输入一行后按 Return；不要删除 placeholder。"
        }
        if key.contains("spotify") {
            return "Spotify：播放/搜索后先重新观察状态；搜索前确认搜索框已聚焦。"
        }
        if key.contains("iphone") || appName.contains("镜像") {
            return "iPhone Mirroring：滚动用 scroll，不用 drag；点击 App 图标中心而不是文字标签。"
        }
        if key.contains("safari") {
            return "Safari：操作网页优先用 DOM 工具（dom_inspect/dom_click/dom_fill）；AppleScript 可获取当前标签页 URL 和标题。"
        }
        if key.contains("chrome") {
            return "Chrome：操作网页优先用 DOM 工具；AppleScript 可获取当前标签页信息。"
        }
        if key.contains("finder") {
            return "Finder：文件操作优先用文件系统工具（list_directory/create_folder/move_file/copy_file/delete_file）；获取选中文件用 get_finder_state。"
        }
        if key.contains("notes") || appName.contains("备忘录") {
            return "备忘录：编辑前先确认选中正确的备忘录；插入文本用类型工具在正文区域输入。"
        }
        if key.contains("mail") || appName.contains("邮件") {
            return "Mail：发送邮件前必须确认收件人和内容；不要自动点击发送按钮。"
        }
        if key.contains("messages") || appName.contains("信息") {
            return "信息：发送前确认会话对象正确；先观察当前会话窗口再操作。"
        }
        if key.contains("calendar") || appName.contains("日历") {
            return "日历：创建事件前先观察当前视图（日/周/月）；确认日期和时间无误再创建。"
        }
        if key.contains("reminders") || appName.contains("提醒") {
            return "提醒事项：添加提醒前先观察当前列表；确认标题和截止时间正确。"
        }
        if key.contains("terminal") || appName.contains("终端") {
            return "终端：执行命令优先用 shell_command 或 terminal_run 工具；不要在终端窗口中使用 type_text 输入命令。"
        }
        if key.contains("xcode") {
            return "Xcode：代码编辑优先用文件工具（read_file/write_file）；导航用 xcode_navigate；构建用 swift_build。"
        }
        if key.contains("pages") {
            return "Pages：编辑文档前先确认光标位置；格式调整用 Format 侧边栏；避免直接操作 Canvas 坐标。"
        }
        if key.contains("keynote") {
            return "Keynote：编辑幻灯片前先选中目标 slide；元素定位使用 Inspector 面板坐标。"
        }
        if key.contains("preview") || appName.contains("预览") {
            return "预览：PDF/图片查看优先用 open_path；标注工具在 Markup 工具栏中。"
        }
        if key.contains("photos") || appName.contains("照片") {
            return "照片：浏览图库用 scroll；选中照片用 click；导出用 File/Export 菜单。"
        }
        if key.contains("settings") || appName.contains("设置") || appName.contains("系统设置") || appName.contains("system settings") {
            return "系统设置：修改设置需要辅助功能权限；优先引导用户手动操作而非自动化。"
        }
        if key.contains("wechat") || appName.contains("微信") {
            return "微信：发送消息用 focus_wechat_message_input 定位输入框；发送前确认会话对象；避免误发敏感内容。"
        }
        if key.contains("vscode") || key.contains("code") && !key.contains("xcode") {
            return "VS Code：代码编辑优先用文件工具；使用 Command Palette (⇧⌘P) 执行命令；终端操作用 shell_command。"
        }
        return nil
    }
}
