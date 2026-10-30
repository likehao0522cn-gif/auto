# Tune Metronome

Accessibility-first tuner and metronome for iPhone, designed for blind and low-vision musicians.

## Current status

- Product specification: `docs/product/functional-spec.md`
- Technical architecture: `docs/technical/architecture.md`
- Implementation status: `docs/technical/implementation-status.md`
- Current session handoff: `docs/technical/handoff-2026-10-30-current.md`
- Glossary: `GLOSSARY.md`
- Architecture decisions: `docs/adr/`
- iOS project: generated from `project.yml` by XcodeGen
- Automated tests: GitHub Actions macOS runner

The codebase currently includes:

- Tuner screen and pitch detection core
- Piano target selection
- Metronome screen and click loop
- Tap tempo area with large direct-touch pad
- Adjustable app speech rate, pitch, and volume
- Chinese VoiceOver labels and focus ordering
- Core pitch, preset, and metronome timing tests

## Verified build

GitHub Actions builds the iOS app, runs the test suites, packages an unsigned IPA, and verifies the SideStore release source:

- Latest release: https://github.com/likehao0522cn-gif/auto/releases/latest
- Successful tagged build: https://github.com/likehao0522cn-gif/auto/actions/runs/40862124863
- SideStore source: https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json

## Install and update without a cable

The test build is distributed through SideStore. The first SideStore installation requires one USB connection; subsequent app updates are wireless.

1. On the iPhone, install LocalDevVPN from the App Store, open it, allow the VPN configuration, and connect.
2. On Windows, install iTunes and the official iloader from its GitHub releases page.
3. Connect the iPhone once by USB, unlock it, and trust the computer.
4. Open iloader, sign in with the Apple Account, select the iPhone, and install SideStore Stable.
5. On the iPhone, trust the developer app, enable Developer Mode when prompted, connect LocalDevVPN, open SideStore, and sign in.
6. In SideStore, refresh SideStore itself once to finish setup.
7. Add this source URL in SideStore:

```text
https://github.com/likehao0522cn-gif/auto/releases/latest/download/source.json
```

8. Install “调音节拍器（测试）”. Future versions can be updated from SideStore without a cable.

Using a free Apple Account requires periodic refresh (normally every 7 days). Official SideStore instructions: https://docs.sidestore.io/docs/installation/install

## Build locally

Requires macOS with Xcode and XcodeGen:

```bash
brew install xcodegen
xcodegen generate
open TuneMetronome.xcodeproj
```
