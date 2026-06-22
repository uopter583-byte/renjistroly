# GitHub Repository Setup

Use this page when publishing RenJistroly on GitHub.

## About

Description:

```text
macOS AI operating assistant with voice input, screen understanding, Accessibility automation, MCP tools, and Developer ID release packaging.
```

Website:

```text
https://github.com/uopter583-byte/renjistroly
```

Topics:

```text
macos
swift
swiftui
ai-assistant
accessibility
mcp
screen-capture
voice-input
desktop-automation
apple-silicon
developer-id
notarization
```

## Short Introduction

RenJistroly is a macOS AI operating assistant. It can understand screen and app context, accept voice input, control desktop applications through macOS Accessibility and Apple Events, run local development tools, and expose an MCP server for compatible AI clients.

It is designed as a developer-preview operating agent: useful for local automation and code workflows, but still intentionally guarded by permission checks, risk scoring, confirmation flows, and audit records.

## Release Notes Template

```markdown
## RenJistroly 0.2.0

Developer-preview macOS release.

### Highlights

- SwiftUI desktop assistant for chat, context, permissions, and workflow control.
- Voice input through microphone and Apple Speech.
- Screen understanding with Accessibility, visible-window context, ScreenCaptureKit, and OCR.
- MCP server and tool registry for local desktop/code capabilities.
- Safety layers for command allowlists, risk scoring, sensitive-app handling, and confirmations.
- Developer ID app and DMG release pipeline with notarization and stapling.

### Install

Download `RenJistroly-0.2.0.dmg`, open it, and copy `RenJistroly.app` to `~/Applications` or `/Applications`.

On first launch, grant the permissions you want to use:

- Accessibility
- Microphone
- Speech Recognition
- Screen Recording and System Audio
- Automation permissions when macOS asks for a specific target app

Restart the app after changing Accessibility or Screen Recording permissions.

### Build From Source

```bash
git clone https://github.com/uopter583-byte/renjistroly.git
cd renjistroly
swift build
swift run RenJistroly
```

### Verification

- App and DMG are Developer ID signed.
- App and DMG are notarized and stapled.
- Targeted permission/screen/voice test suite passes.

### Known Notes

- This is pre-1.0 software.
- Some red-team/security boundary tests are still being hardened.
- Local ASR resources are distributed separately or bundled in signed release artifacts.
- Do not commit signing credentials or provider API keys.
```

## Open Source Publishing Checklist

- Confirm `.gitignore` excludes app bundles, DMGs, build outputs, logs, vendored clones, certificates, and private keys.
- Confirm large generated ASR payloads are ignored or published as release assets, not normal Git blobs.
- Run `Scripts/verify_lfs_assets.sh`.
- Run targeted tests:
  `swift test --scratch-path /private/tmp/renjistroly-release-verify --filter 'Permission|Screen|Voice'`
- Run full `swift test` before marking a stable public release.
- Push source code to `main`.
- Upload the notarized DMG as a GitHub Release asset instead of committing it to Git.
- Add the About description and topics above in GitHub repository settings.
