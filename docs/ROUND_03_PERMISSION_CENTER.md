# Round 03 - Permission Center

Date: 2026-06-14

## Goal

Replace scattered permission checks with a central permission system that can support the Mac desktop-agent product.

## Completed

- Added `PermissionCenter` in `RenJistrolySystemBridge`.
- Added stable permission models:
  - `SystemPermissionKind`
  - `SystemPermissionStatus`
  - `SystemPermissionCheck`
- Added live checks for:
  - Accessibility
  - Microphone
  - Speech Recognition
  - Screen Recording
  - Apple Events
- Added request/open-settings flows for each permission.
- Added `speechRecognition` to `AppState.PermissionGrant`.
- Updated `AppDelegate` to refresh all permissions on launch.
- Upgraded the Settings permission tab with:
  - five permission rows;
  - status labels;
  - request buttons;
  - System Settings buttons;
  - refresh button.
- Added permission contract tests.

## Verification

- `swift build` passed.
- `swift test` passed: 13 tests.
- `SIGNING_MODE=adhoc Scripts/package_app.sh debug` passed.

## Notes

- Apple Events authorization is target-app-specific on macOS. The permission center reports it as `unknown` until a real automation target is requested or a harmless System Events probe succeeds.
- Screen Recording uses `CGPreflightScreenCaptureAccess` and `CGRequestScreenCaptureAccess`.
- Full-agent distribution remains non-sandboxed and should use Developer ID signing/notarization later.

## Next Round

Round 04 should stabilize voice input with a dedicated voice interaction state machine, so the app can handle start, partial transcript, finish, cancel, failure, and submit flows predictably.
