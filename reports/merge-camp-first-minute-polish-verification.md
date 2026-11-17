# First-minute polish verification (feature-first-minute-polish)

Date: 2026-11-17. Spec: `harness/specs/feature-first-minute-polish.md`.

## Changes
- Coach hint strip after the practice merge (`camp_layout.dart` `_captionBar`, `merge_camp_screen.dart` `_coachActive`);
  it lets taps through and is cleared whenever the board returns to zero placements.
- `TileWarmup` (web only) pre-draws tiers 1-5 at the exact real tile size (grid is inset by the board border).
- Initial load: measured in Chrome - `canvaskit.wasm` is already requested before `main.dart.js`; no change made.

## Evidence
- `flutter analyze`: no issues.
- `flutter test`: 330 passed (two consecutive full runs); `flutter test --platform chrome test/web`: 23 passed.
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh`: built, self-checks passed.
- New tests (`test/first_minute_polish_test.dart`): hint lifecycle, skip, restart, tap pass-through, warm-up cadence, and
  warm-up tile size equals real board/preview tile size at DPR 1, 2, 3.
- Independent review: request changes (warm-up size mismatch by 1-3 px). Fixed and covered by the size tests; the fix and
  the new tests were not re-reviewed.

## Not verified
- Real-device effect on first-merge lag and on the CrazyGames conversion rate (needs upload and a few days of data).
- Shader compile on the first merge effects (particles, popups) is not pre-warmed.
- Known pre-existing flake: `daily_camp_screen_test.dart` "a stale streak does not leak into the summary lines"
  failed in about 2 of 3 full runs on the baseline before these changes (passed in the final two runs).
