# RenJistroly Product Architecture

Date: 2026-06-14

## Product Positioning

RenJistroly is a native macOS desktop voice agent for developers and power users.

It is not a smart-speaker clone and not a simple chat window. Its value is that it can understand the current Mac context, reason about the user's intent, operate applications, inspect code projects, run development commands, and report back through text and voice.

## Core Promise

Press a hotkey, speak naturally in Chinese or English, and RenJistroly can:

- understand the active app, window, selection, focused input, screen, and project;
- decide whether the task is chat, writing, code, system control, file work, or app automation;
- show an execution plan when needed;
- ask for confirmation before risky actions;
- execute through native macOS bridges and developer tools;
- return a concise text and voice response.

## Non-Goals for the Early Product

- No always-listening wake word in the first milestone.
- No App Store-first distribution for the full agent.
- No uncontrolled autonomous file edits or shell execution.
- No attempt to replace all of Siri, Shortcuts, or Voice Control.
- No plugin marketplace until the built-in tool chain is reliable.

## Distribution Strategy

### Full Agent

Use Developer ID signing and notarization for direct distribution.

Reason: the full product requires Accessibility, Screen Recording, Apple Events, file access, shell execution, and cross-app automation. These capabilities conflict with the constraints of a Mac App Store sandboxed app.

### Mac App Store Lite

Optional later build with constrained capabilities:

- chat;
- voice dictation;
- writing assistance;
- user-selected file access;
- no broad shell execution;
- no unrestricted cross-app automation.

This version is a discovery and trust channel, not the complete product.

## System Layers

Detailed strategy for learning from Hermes, Ghost OS, swift-computer-use, browser-use, CUA, and Claude Code is captured in `docs/REFERENCE_AGENT_STRATEGY.md`.

### 1. Interaction Layer

Owns the user's immediate experience:

- menu bar presence;
- floating panel;
- main window;
- push-to-talk;
- voice state indicators;
- execution plan display;
- confirmation prompts;
- result summaries.

Current code:

- `Sources/RenJistrolyUI`
- `Sources/RenJistrolyApp`

### 2. Voice Layer

Owns speech input and speech output:

- macOS Accessibility Voice Input as the default speech input path;
- optional built-in speech-to-text fallback;
- text-to-speech;
- voice activity states;
- cancellation and interruption;
- language selection;
- future pluggable local models such as WhisperKit or Parakeet.

Current code:

- `MacOSSpeechRecognizer`
- `MacOSTextToSpeech`
- `SystemDictationBridge`
- `VoiceInputMode`

Hardening:

- stronger voice state machine;
- user-facing voice input mode setting.

### 3. Desktop Context Layer

Collects what the assistant needs to understand the Mac:

- active app;
- focused window;
- focused element role/value;
- selected text;
- UI tree;
- visible windows;
- optional screen capture;
- project context;
- git status.

Current code:

- `AccessibilityBridge`
- `ScreenCaptureBridge`
- `ContextCompiler`
- `DesktopContext`
- `DesktopContextCollector`
- `ComputerUseAppState`
- `ElementRegistry`

Hardening:

- context size limits and redaction;
- visual fallback for weak AX apps.

### 4. Reasoning and Routing Layer

Decides which backend should handle the request and what kind of task it is:

- local deterministic command parsing;
- local LLM;
- Claude Code CLI;
- Anthropic/OpenAI cloud models;
- future model providers.

Current code:

- `SmartRouter`
- `TaskRouter`
- `AgentOrchestrator`
- `LocalMLXBackend`
- `CloudAnthropicBackend`
- `CloudOpenAIBackend`
- `ClaudeCodeBridge`
- `MultiAgentTaskBoard`

Hardening:

- richer route decision logs;
- fallback behavior;
- privacy-aware routing rules.

### 5. Capability Layer

Exposes tools that the agent can call:

- app launching;
- keyboard and mouse control;
- focused text read/write;
- window management;
- UI tree inspection;
- git status/log;
- file read/write;
- shell command execution.

Current code:

- `MCPClient`
- `MCPToolRegistry`
- `SystemTools`
- `ControlTools`
- `CodeTools`
- `ComputerUseRuntime`
- `AppDriverTools`
- `ComputerUseEvalSuite`

Hardening:

- structured arguments beyond `[String: String]`;
- app-specific workflow recipes.

### 6. Safety Layer

Prevents the assistant from becoming reckless:

- classify tools by risk;
- require confirmation for risky actions;
- block destructive commands by default;
- require visible plan before write/shell/send actions;
- preserve user data;
- keep an execution log.

Risk levels:

- Low: read context, list windows, open apps, read selected text.
- Medium: paste text, click UI elements, run read-only commands.
- High: write files, run shell commands, modify git state, send messages, delete or move files.
- Forbidden by default: credential extraction, hidden surveillance, destructive filesystem operations, payment or account actions without explicit user confirmation.

### 7. Persistence Layer

Stores conversations, settings, permissions state, execution logs, workflow memories, and skills.

Current code:

- `SessionManager`
- model types in `RenJistrolyModels`
- `WorkflowMemoryStore`
- `AgentSkillRegistry`
- `SafetyAuditStore`

Hardening:

- settings persistence;
- permission cache with live recheck;
- durable execution history on disk.

## Main Request Flow

1. User invokes RenJistroly through hotkey or menu bar.
2. User speaks or types a request.
3. Voice layer produces text if the request is spoken.
4. Desktop context layer collects the current state.
5. Conversation engine builds the prompt with relevant context.
6. Routing layer selects local, Claude Code CLI, or cloud backend.
7. Reasoning layer produces an answer or tool plan.
8. Safety layer checks risk.
9. UI asks for confirmation when required.
10. Capability layer executes approved tools.
11. Conversation engine summarizes results.
12. UI and TTS return the result.

## Twelve-Round Roadmap

### Round 01 - Engineering Baseline

Status: completed.

Stabilize build, tests, package metadata, and create a durable handoff record.

### Round 02 - Product Architecture

Status: in progress.

Lock the product architecture, module boundaries, release strategy, and roadmap.

### Round 03 - Permission Center

Create a central permission system for Accessibility, Microphone, Speech Recognition, Screen Recording, and Apple Events.

### Round 04 - Voice Input Stability

Replace ad hoc voice state handling with a voice interaction state machine.

### Round 05 - Text-to-Speech

Add native macOS TTS so RenJistroly can speak results.

### Round 06 - Desktop Context

Introduce `DesktopContext` and collect app/window/selection/UI/project state before each turn.

### Round 07 - Tool Safety

Add risk levels, confirmation requirements, and execution policies to tools.

### Round 08 - Execution Plans

Make the assistant show a plan before multi-step or risky actions.

### Round 09 - Developer Mode

Strengthen project reading, test execution, error analysis, and Claude Code integration.

### Round 10 - Floating Panel Experience

Upgrade the UI from a generic chat panel into a focused voice-agent console.

### Round 11 - End-to-End Scenarios

Polish real workflows:

- open an app;
- explain selected text;
- run tests;
- summarize screen context;
- polish and paste text;
- inspect a Swift project.

### Round 12 - Release Preparation

Prepare direct distribution:

- Developer ID signing;
- notarization;
- first-run onboarding;
- privacy and permission copy;
- release checklist.

## Engineering Principles

- Prefer native macOS APIs before web wrappers.
- Keep system control behind explicit tools.
- Make risky actions visible and confirmable.
- Keep local-first routing for private/simple tasks.
- Use cloud models for complex reasoning only when configured.
- Treat the UI as a working cockpit, not a marketing page.
- Keep every round independently verifiable.
