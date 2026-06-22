# Workspace Triage

Generated during cleanup on 2026-06-22.

## Current State

- Tracked changes: 119 files under `Sources`, 77 files under `Tests`, plus package, scripts, docs, entitlements, CI, and project metadata.
- Untracked Swift source: 95 files under `Sources`.
- Untracked Swift tests: 3 files under `Tests`.
- Untracked model resources: 301 files under `Sources/RenJistrolySystemBridge/Resources/NemotronASR`, about 2.4 GB.
- Ignored local reference checkout: `_references/`.
- Removed generated test result residue: `test-results/.last-run.json`.
- Removed stale empty placeholder: `Sources/RenJistrolyCapability/MCPServer/SystemControl/ComputerUseVerification.swift.txt`.

## Keep And Commit In Batches

These are compiled by SwiftPM or are directly tied to compiled code, so they should not be treated as dead files.

- `Sources/RenJistrolyCapability/**`: new MCP tools, tool hooks, app integration tools, code-engine tools, and system-control tools.
- `Sources/RenJistrolySystemBridge/**`: computer-use backends, Chrome/Safari/Finder/system drivers, speech and OCR support, visualizer support.
- `Sources/RenJistrolyIntelligence/**`: command parser split files, prompt/session/provider support.
- `Sources/RenJistrolyModels/**`: new model types for skills, scenarios, operations, schedules, contact center, and set-of-mark overlays.
- `Sources/RenJistrolyUI/**`: design-system components and voice button.
- `Tests/Mocks/MockScrollBridge.swift`, `Tests/UITests/ButtonInteractionTests.swift`, `Tests/UITests/ScrollToolTests.swift`.

Recommended commit groups:

1. Package/product/dead-target cleanup.
2. Warning-free test cleanup.
3. Permission, voice, and screen-capture stability fixes.
4. MCP/tooling expansion.
5. UI design-system and voice controls.
6. Docs, release scripts, and CI metadata.

## Needs A Storage Decision

`Sources/RenJistrolySystemBridge/Resources/NemotronASR` is too large for ordinary Git history.

Preferred options:

1. Move the 2.4 GB model payload to Git LFS.
2. Keep only a manifest plus download/export script in Git.
3. Package the model as a release artifact outside the source repo.

Do not delete it until voice/offline ASR packaging is decided.

Current decision: keep the local payload, add Git LFS attributes for the large
ONNX files, move the exporter to `Scripts/export_nemotron_onnx.py`, and document
the packaging contract in `docs/nemotron-asr-resources.md`. Use
`Scripts/verify_lfs_assets.sh` before staging or packaging the model payload.

## Ignore Or Keep Local Only

These should stay out of normal source commits.

- `_references/`: external reference checkout, now ignored by `.gitignore`.
- `test-results/`: generated test output, now ignored by `.gitignore`.
- `.build*`, `.codebase-memory/`, `.venv_nemo/`, `.claude/worktrees/`, `.config-backups/`, `.understand-anything/`: local build/cache/tooling state.

## Already Removed As Dead Or Generated

- `Sources/RenJistrolyCapability/MCPServer/SystemControl/ComputerUseVerification.swift.txt`: empty excluded placeholder.
- `test-results/.last-run.json`: generated test residue.
- `hello_world.py`: obsolete sample script.
- `Sources/RenJistrolyResources/Localization.swift`: removed with the unused resources target.
- `Sources/RenJistrolyUIPreview/**`: removed with the unused preview target.

## Verification

- `swift test --scratch-path /private/tmp/renjistroly-post-cleanup`
- Result: 1494 XCTest tests, 20 skipped, 0 failures; Swift Testing 5 tests passed.
- Remaining warnings are from Homebrew `onnxruntime` linker/runtime output, not local Swift source warnings.
