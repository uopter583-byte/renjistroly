# Reference Agent Strategy

Date: 2026-06-18

This document preserves the product strategy for learning from adjacent agent projects without turning RenJistroly into a wrapper around any one of them.

## Core Decision

Do not copy or embed Hermes, Ghost OS, browser-use, CUA, or Claude Code wholesale.

RenJistroly should absorb the useful layers from each project:

- Hermes: personal agent memory, skills, self-learning loops.
- Ghost OS: macOS Accessibility tree modeling, app workflows, recovery.
- swift-computer-use: Swift-native macOS computer-use APIs and MCP-style interfaces.
- browser-use: browser-specific agent harness, page state, recovery loops.
- CUA: sandboxing, benchmark tasks, evaluation discipline.
- Claude Code: development agent loop for code, tests, git, PR, CI.

The product stays a native Swift macOS app with its own router, permission model, UI, memory, and execution runtime.

## Layer Mapping

### 1. Mac Hands Layer

Purpose: operate the local Mac reliably.

Primary references:

- Ghost OS
- swift-computer-use
- CUA computer-use interfaces

RenJistroly implementation areas:

- `AccessibilityBridge`
- `ScreenCaptureBridge`
- `ElementRegistry`
- `ComputerUseRuntime`
- `AppDrivers`
- MCP tools such as `get_app_state`, `click`, `set_value`, `scroll`, `drag`

Must improve:

- stable AX tree snapshots;
- element indexing;
- window and app scoping;
- semantic UI element labels;
- visual fallback;
- observe -> act -> verify -> recover loop;
- workflow recipes for common apps.

### 2. Desktop Agent Layer

Purpose: plan and execute user-visible computer tasks.

Primary references:

- Ghost OS
- Hermes computer-use skill design
- swift-computer-use

RenJistroly implementation areas:

- `ComputerUseRuntime`
- `TaskRouter`
- `MultiAgentTaskBoard`
- `SafetyAuditStore`

Must improve:

- task decomposition;
- action verification;
- retry strategy;
- modal and permission recovery;
- app-specific workflows;
- background-safe operation where possible.

### 3. Developer Agent Layer

Purpose: codebase understanding and development execution.

Primary references:

- Claude Code
- Claude Agent SDK
- Claude Code hooks/subagents/MCP/GitHub Actions concepts

RenJistroly implementation areas:

- `ClaudeCodeBridge`
- `ClaudeAgentTool`
- `DeveloperAgentTaskStore`
- `AgentConsoleView` developer-task section

Claude Code is a development engine, not the macOS computer-use runtime.

It should handle:

- read code;
- edit files;
- run tests;
- fix compile errors;
- inspect git;
- summarize diffs;
- generate PR descriptions;
- analyze CI logs.

It should not be the default tool for:

- controlling WeChat;
- clicking System Settings;
- reading arbitrary app AX trees;
- driving Finder/Safari UI;
- voice input;
- TTS;
- macOS permission orchestration.

### 4. Memory and Skills Layer

Purpose: make the app improve with repeated use.

Primary references:

- Hermes Agent
- hermes-agent skill/memory loop

RenJistroly implementation areas:

- `WorkflowMemoryStore`
- `AgentSkillRegistry`
- `AgentSkill`
- `TaskMemory`

Must improve:

- remember successful workflows;
- remember user preferences;
- attach project-specific commands;
- retrieve prior similar tasks;
- record failure causes and recovery steps;
- convert repeated actions into named skills.

### 5. Browser Agent Layer

Purpose: browser tasks should not depend only on raw mouse/keyboard guesses.

Primary references:

- browser-use

RenJistroly implementation areas:

- `OpenURLTool`
- Safari app driver
- future browser DOM/session bridge
- Safari/Chrome app drivers

Must improve:

- page state extraction;
- form filling;
- tab management;
- download handling;
- webpage task recovery;
- handoff between browser-specific tools and macOS-level tools.

### 6. Evaluation Layer

Purpose: make the app know where it fails.

Primary references:

- CUA
- computer-use-agent benchmarks

RenJistroly implementation areas:

- `ComputerUseEvalSuite`
- `ComputerUseEvalTask`
- `ComputerUseEvalResult`
- scripted local benchmark tasks
- safety regression tests
- UI operation replay logs

Must improve:

- benchmark Finder tasks;
- benchmark browser tasks;
- benchmark text-entry tasks;
- benchmark app settings tasks;
- record success rate, retries, and failure reasons;
- block releases when core workflows regress.

## Priority Order

1. Ghost OS-style AX tree and app workflow reliability.
2. swift-computer-use-style Swift-native tool interfaces.
3. Claude Code developer-agent task panel and logs.
4. Hermes-style skills and workflow memory.
5. browser-use-style browser harness.
6. CUA-style benchmark and sandbox evaluation.

## Final Architecture

RenJistroly should become:

- Swift app: voice entry, UI, permissions, safety confirmation, local scheduling.
- Swift Computer Use Runtime: AX/CGEvent/ScreenCaptureKit/AppleScript/app drivers.
- Desktop Agent: observe -> plan -> act -> verify -> recover.
- Claude Code: code editing, test repair, git/PR/CI tasks.
- Hermes-inspired memory: skills, workflow learning, previous task retrieval.
- Browser agent: browser-specific state and actions.
- Eval system: repeated tasks that measure whether the agent is improving.

## Product North Star

The app should feel like a fluent macOS-native partner:

- natural human-machine conversation;
- low-latency text and voice interaction;
- real-time status updates;
- reliable computer control;
- visible plans and confirmations;
- memory of the user's habits;
- safe but not timid execution;
- strong development automation through Claude Code.
