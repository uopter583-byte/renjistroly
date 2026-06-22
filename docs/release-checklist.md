# RenJistroly Release Checklist

Use this checklist for each Developer ID distribution build.

## Preflight

- Run targeted permission and voice tests:
  `swift test --scratch-path /private/tmp/renjistroly-release-verify --filter 'Permission|Screen|Voice'`
- Run the full Swift test suite before cutting a public release.
- Verify large ASR resources:
  `Scripts/verify_lfs_assets.sh`
- Confirm a Developer ID identity is installed:
  `security find-identity -v -p codesigning`
- Confirm notary credentials are stored:
  `xcrun notarytool history --keychain-profile RenJistrolyNotary`

## Release

- Run the release pipeline:
  `Scripts/release_developer_id.sh`
- Confirm the script reports:
  - app codesign verification passed
  - DMG codesign verification passed
  - app Gatekeeper accepted as `Notarized Developer ID`
  - DMG Gatekeeper accepted as `Notarized Developer ID`
  - `hdiutil verify` reports a valid checksum
  - SHA-256 hash is recorded

## Install QA

- Mount the generated DMG.
- Copy `RenJistroly.app` to `~/Applications`.
- Launch only that installed copy.
- Confirm first launch is not blocked by Gatekeeper.
- Confirm permissions in System Settings:
  - Accessibility
  - Microphone
  - Screen Recording and System Audio
- If a new signing identity was used, toggle those permissions off and on once so macOS rewrites TCC records for the new code requirement.
- Restart the app after changing any TCC permission.
- Confirm the app context panel no longer shows red permission state.
- Confirm the microphone button starts and stops recording.
- Confirm screen reading refreshes context.

## Cleanup

- Do not commit certificate, CSR, private key, or `.p12` files.
- Keep signing credentials only in Keychain or an encrypted password manager export.
- Remove temporary notarization archives after release.
- Keep the final DMG and its SHA-256 hash as the release artifact.
