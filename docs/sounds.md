# 提示音系统设计

## 概述

RenJistroly 的提示音系统用于在非前置交互中向用户传递听觉反馈，包括语音响应完成、截屏、操作确认、错误提示等场景。

## 音效分类

| 类型 | 触发场景 | 建议格式 | 时长 |
|------|----------|----------|------|
| `start_listening` | 开始录音 / 等待用户输入 | CAF/AIFF | <0.5s |
| `stop_listening` | 结束录音 / 识别完成 | CAF/AIFF | <0.5s |
| `confirmation` | 操作执行成功 | CAF/AIFF | <1s |
| `error` | 操作失败 / 权限被拒 | CAF/AIFF | <1s |
| `screenshot` | 截屏完成 | CAF/AIFF | <0.3s |
| `tts_done` | TTS 播放完毕 | CAF/AIFF | <0.3s |
| `notification` | 收到消息/通知 | CAF/AIFF | <1s |

## 文件管理

- 音效文件存放于 `Resources/sounds/` 目录
- 格式：Core Audio Format (`.caf`) 或 AIFF (`.aiff`)，44.1kHz, 16bit, mono
- 文件名规则：`{event_type}.caf`
- Assets.xcassets 中通过 `NSDataAsset` 引用

## NSSound 播放方案

```swift
import AppKit

enum SystemSound: String {
    case startListening   = "start_listening"
    case stopListening    = "stop_listening"
    case confirmation     = "confirmation"
    case error            = "error"
    case screenshot       = "screenshot"
    case ttsDone          = "tts_done"
    case notification     = "notification"

    func play() {
        guard let url = Bundle.main.url(
            forResource: rawValue,
            withExtension: "caf",
            subdirectory: "sounds"
        ) else { return }
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        AudioServicesPlaySystemSound(soundID)
    }
}
```

## 可选配置

- UserDefaults key `playSounds` (Bool)，默认 true
- 用户可在设置面板中关闭提示音
- 音量跟随系统「警告音量」或独立控制
