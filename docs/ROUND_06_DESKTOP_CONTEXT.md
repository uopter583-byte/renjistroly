# Round 06 - Desktop Context

Date: 2026-06-14

## Goal

Give each assistant turn a unified view of the current Mac state instead of only sending project context.

## Completed

- Added `DesktopContext` in `RenJistrolyModels`.
- Added supporting models:
  - `DesktopWindow`
  - `DesktopUIElement`
- Added `DesktopContext.promptSummary()` for compact model prompts.
- Added `DesktopContextCollector` in `RenJistrolyConversation`.
- Collected:
  - active app bundle ID;
  - active app name;
  - focused window title;
  - focused element role;
  - focused element value;
  - selected text;
  - current app windows;
  - UI tree summary;
  - project context.
- Updated `ContextCompiler.compileSystemPrompt` to include `DesktopContext`.
- Updated `ConversationEngine` to collect desktop context before normal and Claude Code paths.
- Added `DesktopContextTests`.

## Verification

- `swift build` passed.
- `swift test` passed.

## Notes

- Screen image understanding is not yet included in `DesktopContext`; the current implementation focuses on structured Accessibility and window context.
- The UI tree is capped in prompt summaries to keep prompts compact.

## Follow-Up

- Add redaction for sensitive fields before sending context to cloud models.
- Add explicit screen capture summaries when a vision-capable backend is configured.
