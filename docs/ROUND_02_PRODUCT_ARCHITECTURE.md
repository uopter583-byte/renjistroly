# Round 02 - Product Architecture

Date: 2026-06-14

## Goal

Create a durable product and engineering architecture so future implementation rounds can continue without relying on long chat context.

## Completed

- Defined RenJistroly as a native macOS desktop voice agent rather than a generic chat app or smart-speaker clone.
- Locked the early distribution strategy:
  - full agent through Developer ID signing and notarization;
  - optional Mac App Store Lite build later.
- Defined the seven system layers:
  - interaction;
  - voice;
  - desktop context;
  - reasoning and routing;
  - capability;
  - safety;
  - persistence.
- Defined the main request flow from hotkey/voice input through context collection, routing, tool execution, confirmation, and response.
- Wrote the twelve-round roadmap into `docs/PRODUCT_ARCHITECTURE.md`.

## Verification

- `swift test` passed after documentation changes.

## Next Round

Round 03 should implement a central permission system:

- models for permission kinds and status;
- live checks for Accessibility, Microphone, Speech Recognition, Screen Recording, and Apple Events;
- user-facing opening of the relevant System Settings panes;
- integration with `AppState.PermissionGrant` and the Settings UI.
