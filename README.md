# RenJistroly

RenJistroly is a macOS AI operating assistant. It combines chat, voice input, screen understanding, accessibility automation, local command execution, and MCP tools so an assistant can help with real desktop work instead of only answering inside a chat box.

The project is written in Swift and targets Apple Silicon Macs.

## Why RenJistroly

RenJistroly is built to make **Computer Use** feel tangible on macOS: the model can see useful desktop context, understand the active app, reason about the current screen, and then help operate real UI through guarded local tools.

It is model-provider friendly. You can connect DeepSeek and other OpenAI-compatible LLM endpoints, route tasks through Claude Code CLI, or adapt the provider layer for local and cloud models. The app is not locked to a single model vendor; the desktop control layer, context layer, MCP tools, and UI are separated from the model backend.

RenJistroly can also be pulled into agent workflows directly. Developers can clone this repository, run the macOS app, or build the `RenJistrolyMCP` server and connect it from compatible clients such as Claude Code, OpenClaw, Hermes, or other MCP-capable agent environments.

## What It Does

- Reads desktop context from Accessibility, active windows, focused controls, Finder, browser state, project files, git state, and optional screen OCR.
- Controls macOS apps through Accessibility, AppleScript, keyboard shortcuts, mouse actions, and app-specific drivers.
- Accepts typed prompts, push-to-talk voice input, and continuous voice conversation.
- Supports multiple model backends, including DeepSeek-style OpenAI-compatible endpoints, Claude Code CLI, cloud providers, and local/provider routing.
- Exposes a local MCP server with tools for app control, code tasks, shell execution, OCR, browser automation, file operations, and workflow actions.
- Lets compatible agent clients pull the project and connect to the local MCP/app-control layer instead of reimplementing macOS Computer Use from scratch.
- Adds safety layers: command allowlists, risk scoring, local-only policy, sensitive-app protection, confirmation flows, audit records, and rollback-oriented action results.
- Packages as a Developer ID signed and notarized macOS app.

## Status

RenJistroly is an active pre-1.0 project. The packaged app can be built and notarized, and the core permission, screen, voice, and UI tests pass in the current release verification path. Some broader security/red-team expectations are still being hardened, so treat this as developer-preview software and review high-risk actions before relying on it for production workflows.

Verified on:

- macOS 15+ / Apple Silicon
- Swift 6.x
- Xcode command line tools

## Screens And Permissions

RenJistroly needs explicit macOS permissions for the capabilities you enable:

- Accessibility: read UI trees and control apps.
- Microphone: push-to-talk and continuous voice input.
- Speech Recognition: Apple Speech transcription.
- Screen Recording and System Audio: screen reading, window context, OCR, and screen capture.
- Automation: app-specific Apple Events permissions, granted by macOS per target app.

After changing Accessibility, Microphone, or Screen Recording permissions, restart the app. If you switch signing identities or move the app bundle, macOS may treat it as a new app and require toggling permissions off and on again.

## Install From Source

```bash
git clone https://github.com/uopter583-byte/renjistroly.git
cd renjistroly

swift build
swift run RenJistroly
```

Optional local ASR model payloads are not committed to the source repository. Release builds may include them inside the app bundle. Source builds still compile without those payloads, but local/offline Nemotron ASR features may be unavailable.

## Build The App Bundle

```bash
Scripts/package_app.sh
open RenJistroly.app
```

For a signed and notarized Developer ID release, configure a Developer ID Application certificate and a notarytool keychain profile, then run:

```bash
NOTARY_PROFILE=RenJistrolyNotary Scripts/release_developer_id.sh
```

The release script builds the app, signs it, notarizes it, staples the app, creates a signed DMG, notarizes and staples the DMG, verifies Gatekeeper, and installs a copy to `~/Applications`.

## Run Tests

Targeted release verification:

```bash
swift test --scratch-path /private/tmp/renjistroly-release-verify --filter 'Permission|Screen|Voice'
```

Full test suite:

```bash
swift test
```

Large ASR asset verification:

```bash
Scripts/verify_lfs_assets.sh
```

## Project Layout

```text
Sources/
  RenJistrolyApp              App entry, hotkeys, app lifecycle
  RenJistrolyUI               SwiftUI windows, panels, permission views
  RenJistrolyConversation     Chat/session engine and workflow memory
  RenJistrolyIntelligence     Model backends, routing, context compilation
  RenJistrolyCapability       MCP tools and desktop capability registry
  RenJistrolySystemBridge     macOS Accessibility, ScreenCaptureKit, OCR, shell, app drivers
  RenJistrolyEnterprise       Enterprise modes, policy, action engine
  RenJistrolyProductIdentity  operating scope, trust, test matrix, verification
  RenJistrolyModels           shared models and state
  RenJistrolyMCP              standalone MCP server
  RenJistrolyBridge           CLI bridge for Claude Code-style workflows
  RenJistrolyGate             voice relay helpers
  RenJistrolyHelper           helper service
  RenJistrolyXPC              XPC contracts
  COrt                        ONNX Runtime C wrapper

Tests/
  SecurityTests
  RegressionTests
  UITests
  PerformanceTests
  LongRunningTests
  FaultRecoveryTests
  RenJistroly*Tests
```

## Main User Flows

- Ask about the current desktop context.
- Dictate a command through the microphone button.
- Read the current screen and summarize visible windows/text.
- Insert, copy, or transform selected text.
- Run code-oriented tasks in the current repository.
- Use MCP tools from compatible clients.
- Execute controlled desktop actions with confirmation and audit logging.

## Model And Credential Notes

Do not commit API keys, app-specific passwords, certificates, provisioning files, `.p12` exports, private keys, or notary credentials. Store credentials in Keychain, environment variables, or your own secret manager.

The repository ignores common signing and credential artifacts:

- `*.p12`
- `*.cer`
- `*.pem`
- `*.key`
- `*.certSigningRequest`
- app bundles, DMGs, build outputs, vendored clones, logs, and local reference checkouts

## Large Assets

Generated ASR model payloads under `Sources/RenJistrolySystemBridge/Resources/NemotronASR/` are intentionally ignored. Keep them local, distribute them through signed release artifacts, or publish them as separate release assets. Do not commit large model files as normal Git blobs.

## Documentation

- [Quick start](docs/guides/quickstart.md)
- [Core features](docs/guides/core-features.md)
- [Voice interaction](docs/guides/voice-interaction.md)
- [MCP integration](docs/guides/mcp-integration.md)
- [Enterprise mode](docs/guides/enterprise-mode.md)
- [Release checklist](docs/release-checklist.md)
- [Distribution notes](docs/distribution.md)
- [Security notes](docs/security.md)

## Repository Description

Suggested GitHub description:

```text
macOS AI operating assistant with voice input, screen understanding, Accessibility automation, MCP tools, and Developer ID release packaging.
```

Suggested topics:

```text
macos swift swiftui ai-assistant accessibility mcp screen-capture voice-input desktop-automation apple-silicon
```

## License

MIT. See [LICENSE](LICENSE).
