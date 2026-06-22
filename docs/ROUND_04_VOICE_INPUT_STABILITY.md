# Round 04 - Voice Input Stability

Date: 2026-06-14

## Goal

Make voice input predictable and observable instead of relying on a minimal listen/stop toggle.

## Completed

- Expanded `VoiceInputState` with:
  - `requestingPermission`
  - `transcribing`
  - `speaking`
  - `failed`
- Added state helpers:
  - `isCapturingAudio`
  - `canStartListening`
  - `canFinishListening`
- Added `voiceError` to `ConversationEngine`.
- Updated `ConversationEngine.startVoiceInput` to:
  - surface speech permission failure;
  - report startup errors;
  - keep UI state aligned with the recognition stream.
- Added `cancelVoiceInput`.
- Updated `MacOSSpeechRecognizer.startStreaming` so `AVAudioEngine.start()` errors are thrown instead of silently ignored.
- Updated the main window and floating panel to:
  - show voice error banners;
  - reflect the expanded voice states with icons and colors;
  - restart from a failed state.
- Updated menu bar voice input to call the real conversation engine instead of directly mutating state.
- Added model tests for voice state contracts.

## Verification

- `swift build` passed.
- `swift test` passed: 14 tests.
- `SIGNING_MODE=adhoc Scripts/package_app.sh debug` passed.

## Notes

- The app still uses Apple's `SFSpeechRecognizer` path for STT.
- The voice flow is now visible and testable, but it is still not a full duplex conversation loop.
- Future work should add explicit cancel/submit UI affordances and optional local STT backends.

## Next Round

Round 05 should add native macOS text-to-speech so the assistant can speak concise responses back to the user.
