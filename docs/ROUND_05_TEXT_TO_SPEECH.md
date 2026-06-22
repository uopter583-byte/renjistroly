# Round 05 - Text-to-Speech

Date: 2026-06-14

## Goal

Add native macOS speech output so RenJistroly can speak concise responses when the user enables voice replies.

## Completed

- Added `MacOSTextToSpeech` in `RenJistrolySystemBridge`.
- Used `AVSpeechSynthesizer`, Apple's current speech synthesis API for macOS 15+.
- Added support for:
  - speaking text;
  - stopping current speech;
  - checking active speech state;
  - listing available voice identifiers.
- Added `isVoiceOutputEnabled` to `AppState`.
- Added a Settings toggle for voice replies.
- Updated `ConversationEngine` to:
  - optionally speak final assistant responses;
  - set voice state to `speaking`;
  - return voice state to `idle` when speech completes;
  - stop voice output on demand.
- Updated main window and floating panel message sends to pass `AppState` into the conversation engine.

## Verification

- `swift build` passed.
- `swift test` passed: 14 tests.
- `SIGNING_MODE=adhoc Scripts/package_app.sh debug` passed.

## Notes

- Voice replies are disabled by default to avoid surprising the user.
- TTS currently speaks the full final response. Future UI should support "speak summary only" and a visible stop button.
- The first attempted implementation used `NSSpeechSynthesizer`, but it is deprecated on macOS 14+. The implementation was replaced with `AVSpeechSynthesizer`.

## Next Round

Round 06 should introduce a unified `DesktopContext` collected before each conversation turn.
