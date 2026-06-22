# Round 01 - Engineering Baseline

Date: 2026-06-14

## Goal

Stabilize the current project baseline before adding new product capabilities.

## Completed

- Reproduced the failing `SmartRouter` test.
- Fixed the Swift Testing assertion shape in `SmartRouterTests` without changing production routing logic.
- Verified `swift test` passes.
- Verified `swift build` passes.
- Verified `Scripts/package_app.sh debug` creates `RenJistroly.app`.
- Aligned packaged app metadata with the SwiftPM target:
  - `CFBundleExecutable` is `RenJistroly`.
  - minimum macOS version is `15.0`.
  - accessibility and screen capture usage descriptions are included.

## Verification

- `swift test` passed: 10 tests.
- `swift build` passed.
- `SIGNING_MODE=adhoc Scripts/package_app.sh debug` passed.
- Packaged binary: `RenJistroly.app/Contents/MacOS/RenJistroly`, arm64.
- Packaged signing: ad-hoc.

## Notes

- The repository is not currently a Git repository, so there is no local commit state to inspect.
- The current app entitlements are broad and intentionally non-sandboxed. That supports the full desktop-agent direction but is not suitable for a Mac App Store build without a separate constrained distribution target.
- The existing test suite is still shallow. Future rounds should add tests around permission state, tool risk classification, desktop context collection, and voice state transitions.

## Next Round

Round 02 should lock the product architecture and create a development roadmap that future rounds can follow without relying on long chat context.
