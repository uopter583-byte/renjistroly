import SwiftUI
import RenJistrolyModels

public struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var step = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                welcomeStep.tag(0)
                permissionsStep.tag(1)
                hotkeyStep.tag(2)
                tipsStep.tag(3)
            }
            .tabViewStyle(.grouped)

            HStack {
                stepDots
                Spacer()
                actionButton
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 520, height: 420)
        .background(Color(.windowBackgroundColor))
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var actionButton: some View {
        Button {
            if step < 3 {
                withAnimation { step += 1 }
            } else {
                appState.completeOnboarding()
            }
        } label: {
            Text(step < 3 ? "继续" : "开始使用")
                .frame(minWidth: 80)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 20)
        .background(Color.accentColor)
        .foregroundColor(.white)
        .cornerRadius(6)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("欢迎使用 RenJistroly")
                .font(.system(size: 22, weight: .bold))

            Text("你的 Mac 智能语音代理，可以直接操控应用、\n编写代码、读写文件、运行终端命令。")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                featureRow("mic.fill", "语音交互", "按住说话，松开执行")
                featureRow("macwindow", "系统控制", "打开应用、点击按钮、输入文字")
                featureRow("chevron.left.forwardslash.chevron.right", "代码辅助", "构建运行、解释代码、润色替换")
                featureRow("slider.horizontal.3", "执行计划", "多步任务自动编排执行")
            }
        }
        .padding(.top, 40)
    }

    private var permissionsStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundColor(.orange)

            Text("授予权限")
                .font(.system(size: 20, weight: .bold))

            Text("RenJistroly 需要以下系统权限才能正常工作")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                permRow("accessibility", "辅助功能", "读取界面、控制应用", appState.isPermissionGranted.accessibility)
                permRow("mic", "麦克风", "语音输入", appState.isPermissionGranted.microphone)
                permRow("captions.bubble", "语音识别", "转写语音为文字", appState.isPermissionGranted.speechRecognition)
                permRow("rectangle.on.rectangle", "屏幕录制", "读取屏幕内容", appState.isPermissionGranted.screenRecording)
                permRow("apple.logo", "Apple Events", "自动化操作", appState.isPermissionGranted.appleEvents)
            }

            Text("首次启动时会自动提示，也可在系统设置中手动开启。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.top, 30)
    }

    private var hotkeyStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "command")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)

            Text("全局快捷键")
                .font(.system(size: 20, weight: .bold))

            Text("随时唤起 RenJistroly 浮窗")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                KeyboardKey("⌥")
                Text("+")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                KeyboardKey("Space")
            }

            Text("按住 Option+空格 说话，松开后自动执行。\n在任何应用中都可以使用。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("状态栏也有 RenJistroly 图标，点击即可访问。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }

    private var tipsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)

            Text("快速上手")
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 12) {
                tipRow("1", "打开应用", "\"打开 Safari\"")
                tipRow("2", "控制界面", "\"在终端输入 ls 并回车\"")
                tipRow("3", "润色文字", "选中文字，点击 ✨ 或说\"润色这段\"")
                tipRow("4", "解释代码", "选中代码，点击 💬 或说\"解释这段\"")
                tipRow("5", "读屏幕", "点击 👁 或说\"读屏幕\"")
            }

            Text("试试看！不满意随时按 Option+Space 重新说。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.top, 30)
    }

    // MARK: - Helpers

    private func featureRow(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
    }

    private func permRow(_ icon: String, _ title: String, _ desc: String, _ granted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(granted ? .green : .orange)
                .frame(width: 20)
            Text(title).font(.system(size: 13))
            Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(granted ? .green : .secondary)
                .font(.system(size: 12))
        }
    }

    private func tipRow(_ num: String, _ title: String, _ example: String) -> some View {
        HStack(spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 70, alignment: .leading)
            Text(example)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

private struct KeyboardKey: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            )
    }
}
