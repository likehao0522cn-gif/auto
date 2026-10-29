# Tune Metronome

Accessibility-first tuner and metronome for iPhone.

## Current status

- Product specification: `docs/product/functional-spec.md`
- Technical architecture: `docs/technical/architecture.md`
- Implementation status: `docs/technical/implementation-status.md`
- Glossary: `GLOSSARY.md`
- Architecture decisions: `docs/adr/`
- iOS project: generated from `project.yml` by XcodeGen
- Automated tests: GitHub Actions macOS runner

The codebase currently includes:

- Tuner screen and pitch detection core
- Piano target selection
- Metronome screen and basic click loop
- Tap tempo area
- Initial VoiceOver labels and focus order
- Core pitch, preset, and metronome timing tests

## Verified build

GitHub Actions successfully builds the iOS app and runs 26 core tests:

https://github.com/likehao0522cn-gif/auto/actions/runs/40051338829

## Install on a device without a paid Apple Developer account

The workflow writes an unsigned IPA artifact named `TuneMetronome-unsigned`.

1. Download the artifact from the latest successful GitHub Actions run.
2. Install AltStore on a Windows PC and iPhone.
3. On Windows, install iTunes from Apple's website (not the Microsoft Store build).
4. Connect the iPhone by USB and trust the computer.
5. In AltStore, sign in with the Apple ID used on the iPhone.
6. Install the unsigned IPA with AltStore.
7. On the iPhone, open Settings > General > VPN & Device Management and trust the developer certificate.
8. The app remains installed for 7 days, then must be re-signed.

AltStore uses a free Apple ID and does not require the paid Apple Developer Program. A Mac is not required. The unsigned IPA file is kept out of Git; download it from the GitHub Actions artifact.

## Build locally

Requires macOS with Xcode and XcodeGen:

```bash
brew install xcodegen
xcodegen generate
open TuneMetronome.xcodeproj
```