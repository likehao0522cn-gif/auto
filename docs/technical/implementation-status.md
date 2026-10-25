# Implementation Status

Updated: 2026-10-25

## Implemented

- SwiftUI application shell and home screen
- Tuner screen
- Instrument, string, and piano target selection
- Pitch detection core using a YIN-style autocorrelation detector
- Note name, cent offset, and tolerance calculation
- Event-based tuning feedback and haptic feedback scaffolding
- Reference tone playback
- Metronome screen
- Time signature, accent, subdivision, and count-in settings
- Three metronome timbres
- Optional haptic ticks that follow the beat pattern
- Count-in feedback and status
- AVAudioEngine-based metronome click loop
- Tap tempo area and BPM estimation
- Settings and help screens
- Initial VoiceOver labels and focus ordering
- Note naming setting (letter names or fixed solfege) applied to UI and speech
- Reference tone timbre setting applied to playback
- Help overlay pauses tuning and resumes on dismiss
- Restore-defaults action
- Core unit tests
- GitHub Actions macOS build and test workflow
- XcodeGen project configuration

## Verified

- 2026-10-25: GitHub Actions `iOS CI` completed successfully with the latest metronome timbre, haptics, and count-in changes.
- Run: https://github.com/likehao0522cn-gif/auto/actions/runs/40162443723
- Latest unsigned IPA was produced and downloaded locally to `artifacts/TuneMetronome-unsigned.ipa`.
- SwiftPM and Xcode Simulator tests pass.
- Unit test coverage: note and cent conversion, A4 calibration, instrument presets, pitch detection (low, mid, high, noise, performance), metronome timing, subdivisions, and tap tempo.

## Not Yet Complete or Verified

- No signed TestFlight build has been produced yet.
- Volume-button tap tempo is not implemented.
- Real VoiceOver speech, overlap, and device focus order are not verified.
- Haptic feedback is not verified on a physical device.
- Metronome background playback, lock screen behavior, and audio routing are not verified.
- Piano bass accuracy and real instrument timbres are not verified.
- Guzheng and pipa string data still need final review.
- Full Chinese and English localization is not implemented.
- App icon, final product name, and App Store configuration are not complete.

## Next Milestones

1. Configure Apple Developer signing and App Store Connect.
2. Produce a TestFlight build.
3. Verify microphone, VoiceOver, haptics, and background playback on iPhone.
4. Fix device-specific issues and repeat TestFlight.