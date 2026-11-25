# Verification: faster merge timing and Daily Camp

- Specs: `harness/specs/feature-merge-feel-timing.md`, `harness/specs/feature-daily-camp.md`
- ADRs: `adr-merge-camp-flutter-foundation`, `adr-run-snapshot` (addendum), `adr-merge-camp-crazygames-web`
- Date: 2026-11-13. Base: `d3d6ec8`.
- Why: CrazyGames Basic Launch 2026-11-06..12 gave Desktop 5/15 and Mobile 4/15
  (average playtime 5m01 / 4m30, D1 retention 1.44% / 0.00%). See
  `reference-crazygames-basic-launch` in the project memory.

## Checks run

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub` | 322 passed (new: timing, daily rules, controller sequence and snapshot, progress settlement, screen flows, 7 summary layouts) |
| `flutter test --no-pub --platform chrome test/web` | 23 passed, including `daily_camp_parity_test.dart` (VM and web draw the same sequence) |
| `tool/build_crazygames.sh` | Built, 37 files, about 18.6 MB |
| `flutter build web --release --base-href /MergeCamp/` | Built; no CrazyGames SDK in `index.html` |
| Local Chrome render of the CrazyGames build (1568x706) | Six menu buttons fit in the side panel; the Daily button shows its dot |

## Run length estimate (bot simulation, 400 seeds, real controller)

Random placement: 27 / 36 / 48 placements (p10 / p50 / p90), mean 37.6.
Greedy (merge-count based): 33 / 46 / 62, mean 46.3. At roughly 2-4 s per human
placement a run lasts about 1.5-3 minutes, so a 4.5-5 minute average session is
about two runs. Humans were not measured. The portal gives no per-run data and
the game has no network, so no run-length logging was added.

## Not verified

- Real-device (iPhone Safari, mid-range Android) frame time and how the
  shorter timeline feels. The timing change was only checked by unit test.
- Phone-width visual check of the header with six buttons (only widget tests at
  320x640 up to 1366x768, no overflow).
- Whether the Daily Camp moves D1 retention or playtime. It can only be
  measured on the portal after release.
- The thumbnail/CTR issue (0.4%, bottom 20%) is not addressed in code.

## Review follow-up

Independent review (approve with comments, no Critical/High) found: stale
"Today's best" and "Tomorrow" lines in the summary, "Try again" after midnight
replaying the previous day's camp, and a test that passed for the wrong reason.
All three were fixed (summary lines now use the run's day and the streak rules,
below-bar daily runs keep their score as the day's best, retry after midnight
uses today's camp) and covered by new tests. The fixes were not re-reviewed.
Known and accepted: the offline local-clock design lets a player move the
clock forward to claim a daily per fake day.

## Summary hook fix (2026-11-25)

Commit 4ee7cd2 was written on a PC where `flutter test` could not run. On macOS
four tests failed: the summary hook test searched for "play today's daily camp"
while a zero-streak hook reads "Play today's daily camp..." (matcher fixed), and
the summary at 844x390 overflowed by 14 px in `ui_screen_test`,
`result_share_test` and `decor_stickers_test`. The wide and compact action
column now uses smaller button heights and gaps and scrolls as a fallback;
portrait summaries keep their sizes. `result_share_test` asserts the action
column does not scroll at the wide sizes (it fails with the trims turned off).
Independent review: approve with comments, no Critical/High; its test-gap,
scope, matcher and comment notes were applied. `flutter analyze`: no issues.
`flutter test`: 440 passed.
