# Verification: feature-quality-guideline-polish

Date: 2026-11-26. Base: b69dcb4.

## Source
CrazyGames quality guidelines (docs.crazygames.com/requirements/quality), compared with a fresh-storage first run of the
draft build at 1100x620 (desktop iframe) and 390x760 (phone) in Chrome.

## Checks
| Check | Command / method | Result |
|---|---|---|
| Static analysis | `flutter analyze` | exit 0, no issues |
| Full tests | `flutter test` | exit 0, 448 tests pass |
| Q1 AZERTY cursor | `test/keyboard_controls_test.dart` "WASD follows key positions on an AZERTY keyboard" | pass; fails on the old logical-key code |
| Q2 AZERTY Shift | `test/camp_shift_test.dart` "AZERTY Z (the W key position) shifts up" | pass; fails on the old code |
| Q3 preview label | `test/first_run_resume_test.dart` (one-step: no label; two-step: "Chain x2", font >= 11) | pass; Chain x2 test fails on the old code |
| Q4 desktop toasts | `test/first_minute_rewards_test.dart` "desktop first merge keeps every visible toast whole" (1100x620) | pass; fails on the old layout |
| CrazyGames build | `tool/build_crazygames.sh` | exit 0, 37 files, 18.6 MB |
| Browser | fresh storage, 1100x620, first guided merge | banner plus the newest toast, both whole; before the fix the newest toast was cut off |

## Independent review
`code-reviewer` (2026-11-26): approve with comments, no Critical or High findings. All four comments are fixed:
- Medium: "Chain xN" wrapped and lost its count on small cells. It now falls back to "xN", with no wrapping. Tests run at 390x844, 360x640 and 640x360.
- Medium: toasts hidden while the banner showed were delayed or replayed. They now stay mounted invisibly with their own timers, and a test checks that nothing shows again after the banner.
- Low: position-based WASD overrode E on Dvorak. Letter bindings R, C, X and E now take precedence, with a test.
- Low: a vacuous no-op assertion in the AZERTY test. It now runs from cell 5.

Each new test fails on the earlier version of its fix (mutation check).

## Not verified
- A real AZERTY keyboard (tests use synthetic key events with AZERTY logical/physical pairs).
