import Foundation
import ServiceManagement
import RenJistrolyXPC

@MainActor
public final class UpdateManager: ObservableObject {
    @Published public var helperStatus: HelperStatus = .unknown

    private var connection: NSXPCConnection?

    public enum HelperStatus: Sendable {
        case unknown
        case notInstalled
        case installed
        case installing
        case connected
        case error(String)
    }

    public init() {}

    // MARK: - XPC Connection

    private func connect() -> NSXPCConnection? {
        if let conn = connection {
            return conn
        }

        let conn = NSXPCConnection(
            machServiceName: XPCConstants.machServiceName,
            options: .privileged
        )
        conn.remoteObjectInterface = NSXPCInterface(with: RenJistrolyHelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.helperStatus = .notInstalled
            }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
            }
        }
        conn.resume()
        connection = conn
        return conn
    }

    private func proxy() -> RenJistrolyHelperProtocol? {
        guard let conn = connect() else { return nil }
        return conn.remoteObjectProxyWithErrorHandler { [weak self] error in
            Task { @MainActor in
                self?.connection = nil
                self?.helperStatus = .error("XPC 连接失败: \(error.localizedDescription)")
            }
        } as? RenJistrolyHelperProtocol
    }

    // MARK: - SMAppService (macOS 13+, replaces SMJobBless)

    public func installHelper() -> Bool {
        helperStatus = .installing

        #if DEBUG
        guard isSigned else {
            helperStatus = .error("安装 Helper 需要代码签名。Debug 模式下请使用 adhoc 签名。")
            return false
        }
        #endif

        do {
            try SMAppService.daemon(plistName: XPCConstants.helperBundleID).register()
        } catch {
            helperStatus = .error("注册失败: \(error.localizedDescription)")
            return false
        }

        helperStatus = .installed
        return true
    }

    private var isSigned: Bool {
        guard let info = Bundle.main.infoDictionary else { return false }
        return (info["SignerIdentity"] as? String)?.isEmpty == false
    }

    // MARK: - Health Check

    public func checkHelperStatus() async {
        guard let p = proxy() else {
            helperStatus = .notInstalled
            return
        }

        let ok: Bool = await withCheckedContinuation { cont in
            p.ping { ok in cont.resume(returning: ok) }
        }

        helperStatus = ok ? .connected : .notInstalled
    }

    // MARK: - Update Operations

    public func installUpdate(packagePath: String, targetBundlePath: String) async -> (Bool, String) {
        guard let p = proxy() else {
            return (false, "无法连接 Helper")
        }

        return await withCheckedContinuation { cont in
            p.installUpdate(packagePath: packagePath, targetBundlePath: targetBundlePath) { ok, msg in
                cont.resume(returning: (ok, msg))
            }
        }
    }

    public func verifySignature(of bundlePath: String) async -> (Bool, String) {
        guard let p = proxy() else {
            return (false, "无法连接 Helper")
        }

        return await withCheckedContinuation { cont in
            p.verifyAppSignature(bundlePath: bundlePath) { ok, msg in
                cont.resume(returning: (ok, msg))
            }
        }
    }

    public func restartApp(bundlePath: String) async -> Bool {
        guard let p = proxy() else {
            return false
        }

        return await withCheckedContinuation { cont in
            p.restartApp(bundlePath: bundlePath) { ok in
                cont.resume(returning: ok)
            }
        }
    }
}
