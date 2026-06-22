import Foundation

@objc(RenJistrolyHelperProtocol)
public protocol RenJistrolyHelperProtocol: NSObjectProtocol {
    func installUpdate(
        packagePath: String,
        targetBundlePath: String,
        reply: @escaping (Bool, String) -> Void
    )

    func verifyAppSignature(
        bundlePath: String,
        reply: @escaping (Bool, String) -> Void
    )

    func restartApp(
        bundlePath: String,
        reply: @escaping (Bool) -> Void
    )

    func ping(reply: @escaping (Bool) -> Void)
}
