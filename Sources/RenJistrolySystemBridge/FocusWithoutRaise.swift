import AppKit
import Foundation

/// Put a target app into AppKit-active state without asking WindowServer
/// to reorder windows and without triggering macOS "Switch to a Space" behavior.
///
/// Recipe (ported from yabai):
/// 1. `_SLPSGetFrontProcess(&prevPSN)` — capture current front
/// 2. `GetProcessForPID(targetPid, &targetPSN)`
/// 3. Post 248-byte defocus record to previous front, then focus record to target
/// 4. Target becomes AppKit-active without window raise or Space follow
public enum FocusWithoutRaise {

    /// Put `targetPid` into AppKit-active state without raising its windows.
    /// Returns true when all SPIs resolved and the focus event was posted.
    @discardableResult
    public static func activateWithoutRaise(
        targetPid: pid_t,
        targetWid: CGWindowID = 0
    ) -> Bool {
        guard SkyLightEventPost.isFocusWithoutRaiseAvailable else { return false }

        let prevPSN = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 8)
        defer { prevPSN.deallocate() }
        let targetPSN = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 8)
        defer { targetPSN.deallocate() }

        guard SkyLightEventPost.getFrontProcess(prevPSN) else { return false }
        guard SkyLightEventPost.getProcessPSN(forPid: targetPid, into: targetPSN) else { return false }

        var buf = [UInt8](repeating: 0, count: 248)
        buf[0x04] = 0xf8
        buf[0x08] = 0x0d

        // Defocus previous front
        buf[0x8a] = 0x02
        SkyLightEventPost.postEventRecordTo(psn: prevPSN, bytes: &buf)

        // Focus target — stamp window ID at bytes 0x3c-0x3f (little-endian)
        if targetWid != 0 {
            var wid = targetWid
            withUnsafeBytes(of: &wid) { widBytes in
                buf[0x3c] = widBytes[0]; buf[0x3d] = widBytes[1]
                buf[0x3e] = widBytes[2]; buf[0x3f] = widBytes[3]
            }
        }
        buf[0x8a] = 0x01
        SkyLightEventPost.postEventRecordTo(psn: targetPSN, bytes: &buf)

        return true
    }
}
