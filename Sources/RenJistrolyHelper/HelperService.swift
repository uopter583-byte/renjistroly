import Foundation
import RenJistrolyXPC
import OSLog
import Security

final class HelperService: NSObject, RenJistrolyHelperProtocol, NSXPCListenerDelegate {

    /// 允许安装的目标路径前缀
    private static let allowedInstallPrefixes: [String] = [
        "/Applications/",
        NSHomeDirectory() + "/Applications/",
    ]

    /// 允许的更新包路径前缀
    private static let allowedPackagePrefixes: [String] = [
        "/tmp/",
        "/private/tmp/",
        NSTemporaryDirectory(),
        "/Applications/",
        NSHomeDirectory() + "/Applications/",
        NSHomeDirectory() + "/Library/",
        NSHomeDirectory() + "/Downloads/",
    ]

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // 仅接受来自 com.renjistroly.app 的连接
        guard validateConnection(newConnection) else {
            os_log(.error, "[HelperService] 拒绝未授权的 XPC 连接")
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: RenJistrolyHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    /// 通过代码签名验证连接进程的身份
    private func validateConnection(_ connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        guard pid > 0, pid != ProcessInfo.processInfo.processIdentifier else { return false }

        var code: SecCode?
        let attrs = [kSecGuestAttributePid: NSNumber(value: pid)] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess,
              let code else {
            return false
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess else {
            return false
        }

        // 要求连接进程必须是 com.renjistroly.app
        let requirementString = "anchor apple generic and identifier \"com.renjistroly.app\""
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementString as CFString, [], &requirement) == errSecSuccess else {
            return false
        }

        let status = SecStaticCodeCheckValidity(staticCode!, [], requirement!)
        return status == errSecSuccess
    }

    /// 验证路径是否在允许的目录范围内（防止路径遍历）
    private func isPathInAllowedPrefixes(_ path: String, allowedPrefixes: [String]) -> Bool {
        let resolved = URL(fileURLWithPath: path).standardized.path
        return allowedPrefixes.contains { resolved.hasPrefix($0) }
    }

    /// 验证更新包的代码签名（防止安装恶意软件）
    private func verifyPackageSignature(at path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--verbose=4", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Protocol methods

    func ping(reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func installUpdate(packagePath: String, targetBundlePath: String, reply: @escaping (Bool, String) -> Void) {
        let fm = FileManager.default
        let tempPath = packagePath
        let destPath = targetBundlePath

        // 1. 路径安全检查：更新包必须在允许的路径下
        guard isPathInAllowedPrefixes(tempPath, allowedPrefixes: Self.allowedPackagePrefixes) else {
            reply(false, "更新包路径不允许: \(tempPath)")
            return
        }

        // 2. 路径安全检查：目标路径必须在 /Applications 下
        guard isPathInAllowedPrefixes(destPath, allowedPrefixes: Self.allowedInstallPrefixes) else {
            reply(false, "目标路径不允许: \(destPath)")
            return
        }

        // 3. 验证更新包的代码签名
        guard verifyPackageSignature(at: tempPath) else {
            reply(false, "更新包签名验证失败，拒绝安装")
            return
        }

        guard fm.fileExists(atPath: tempPath) else {
            reply(false, "更新包不存在: \(tempPath)")
            return
        }

        guard fm.fileExists(atPath: destPath) else {
            reply(false, "目标应用不存在: \(destPath)")
            return
        }

        do {
            if fm.fileExists(atPath: destPath) {
                try fm.removeItem(atPath: destPath)
            }
            try fm.copyItem(atPath: tempPath, toPath: destPath)

            try fm.removeItem(atPath: tempPath)

            reply(true, "更新已安装，请重启应用。")
        } catch {
            reply(false, "安装失败: \(error.localizedDescription)")
        }
    }

    func verifyAppSignature(bundlePath: String, reply: @escaping (Bool, String) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--verbose=4", bundlePath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                reply(true, "签名验证通过")
            } else {
                reply(false, "签名验证失败: \(output)")
            }
        } catch {
            reply(false, "无法执行签名验证: \(error.localizedDescription)")
        }
    }

    func restartApp(bundlePath: String, reply: @escaping (Bool) -> Void) {
        // 路径安全检查：仅允许重启 /Applications 下的应用
        guard isPathInAllowedPrefixes(bundlePath, allowedPrefixes: Self.allowedInstallPrefixes) else {
            reply(false)
            return
        }

        nonisolated(unsafe) let r = reply

        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: 0.5)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [bundlePath]

            do {
                try process.run()
                r(true)
            } catch {
                #if DEBUG
                os_log(.error, "[HelperService] 重启失败: %{public}@", error.localizedDescription)
                #endif
                r(false)
            }
        }

        exit(0)
    }

}
