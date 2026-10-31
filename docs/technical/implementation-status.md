# Implementation Status

Updated: 2026-10-29

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
- Restore-defaults actions for tuning and metronome
- In-app diagnostics page with device, permission, audio route, and settings summary
- Tuner microphone is released whenever the app leaves the foreground or the tuner page is not visible
- Tuner recovers from microphone permission changes, audio interruptions, and output route changes
- In-tune earcon, direction-change full announcements, and low-confidence feedback
- Piano automatic mode shows "自动识别" instead of a fixed target
- Tap tempo plays a short confirmation click for each tap
- Volume-button tap tempo is wired through the system volume observer and restores the user volume after each tap
- Piano multiple-note warning uses conservative independent-peak detection
- Metronome haptics follow the audio player's rendered time instead of accumulating timer drift
- Core unit tests
- GitHub Actions macOS build and test workflow
- 可调节数值统一使用大号“减 / 加”按钮：语音语速、语音音调、语音音量、标准音高和节拍器速度。
- XcodeGen project configuration

## Verified

- 2026-10-25: GitHub Actions `iOS CI` completed successfully with diagnostics, metronome timbres, haptics, and stable realtime pitch analysis.
- Run: https://github.com/likehao0522cn-gif/auto/actions/runs/40163213296
- 2026-10-27: GitHub Actions `iOS CI` completed successfully after tuner lifecycle and audio recovery changes.
- Run: https://github.com/likehao0522cn-gif/auto/actions/runs/40492063037
- 2026-10-29: GitHub Actions `iOS CI` completed successfully after stabilizing the multiple-pitch performance test and adding the accessibility build marker.
- Run: https://github.com/likehao0522cn-gif/auto/actions/runs/40804176824
- Latest verified unsigned IPA was downloaded locally to `artifacts/TuneMetronome-latest-d0d83c5.ipa` (SHA-256 `C02986740A5EE3094CC54179EE087C12E4E88F9C48B1053DCD3E0C03A60A4557`).
- IPA metadata and main binary were checked for display name, version, bundle ID, build marker, and current Chinese UI strings.
- SwiftPM and Xcode Simulator tests pass.
- Unit test coverage: note and cent conversion, A4 calibration, instrument presets, pitch detection (low, mid, high, noise, performance), metronome timing, subdivisions, tap tempo, and tuning feedback.

## Not Yet Complete or Verified

- No signed TestFlight build has been produced yet.
- Volume-button tap tempo is implemented but must be verified on a physical iPhone; iOS may block volume interception in some configurations.
- Piano multiple-note detection is conservative and needs validation with recorded piano samples; it intentionally prefers false negatives over false warnings.
- Metronome haptics are audio-time based but still require physical-device latency validation.
- English localization is not implemented; the English option is disabled and clearly labelled as unavailable.
- Real VoiceOver speech, overlap, and device focus order are not verified.
- Haptic feedback is not verified on a physical device.
- Metronome background playback, lock screen behavior, and audio routing are not verified.
- Piano bass accuracy and real instrument timbres are not verified.
- Guzheng and pipa string data still need final review.
- App icon, final product name, and App Store configuration are not complete.

## 2026-10-31 本地待验证改动

- 新增 `App/Sources/AdjustableValueRow.swift`。
- 语音语速、音调、音量、标准音高和节拍器速度改为大号“减 / 加”按钮。
- 每个加减按钮都有独立中文旁白标签；到达边界时按钮禁用；旁白开启时调整后播报新值。
- 上述改动尚未经过 GitHub Actions 构建和真机 VoiceOver 验证，也尚未推送。

## Next Milestones

1. Configure Apple Developer signing and App Store Connect.
2. Produce a TestFlight build.
3. Verify microphone, VoiceOver, haptics, and background playback on iPhone.
4. Fix device-specific issues and repeat TestFlight.
