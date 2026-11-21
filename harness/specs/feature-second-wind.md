---
id: feature-second-wind
title: MergeCamp Second Wind (rewarded-ad continue when the board locks up)
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
  - adr-run-snapshot
  - adr-merge-camp-crazygames-web
related_contracts:
  - contract-merge-camp-mvp
  - contract-merge-camp-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
---

# Feature: Second Wind

## Problem
CrazyGames rejected MergeCamp in Basic Launch (2026-11-19) for missing the performance benchmarks.
Average playtime was 5m01 on desktop (needs 8m01) and 4m30 on mobile (needs 6m42).
A bot with a simple adjacency heuristic ends a run after a median of 86 placements, and softening the tier-cap
ramp (the cap rises every 8 placements) or the spawn weights moved that median by only +6..+15 placements,
so tuning alone cannot lengthen a run enough. A locked board ends the run immediately; there is no way to keep going.

## Scope
1. Offer: when a run ends because the board is full with no Trail Axe, and the platform can show a rewarded ad
   (`GamePlatform.supportsRewardedAds`, CrazyGames builds only), the run does not settle yet. A "Second Wind" card
   asks to watch a short video to clear 6 camps and keep playing, with "Watch video to continue" and "End run" of the same size.
   - CrazyGames rules (docs.crazygames.com/requirements/ads, /resources/rewarded-ads-deep-dive, read 2026-11-21): a revive may not be offered on every death and is limited to once per session, the offer must sit on a break screen, the skip must match the watch button's size and font, nothing may reward on `adError`, and Basic Launch must not show rewarded buttons that do nothing (the SDK answers `adsDisabled` there).
   - So it is offered at most once per session (page load), only after at least 20 placements, never in guided practice.
   - Only builds made with `CRAZYGAMES_REWARDED=true` (Full Launch) offer it; the default build and any platform that answered `adsDisabled` never do.
   - While the card is open the run is not settled: no XP, no best score, no streak, no leaderboard, no run-break ad.
2. Continue: `GamePlatform.showRewardedAd()` completes with true only when the player watched the ad to the end.
   On true the controller clears the 6 lowest-tier camps (ties: lowest cell index first) and the run resumes:
   score, placements, tools, pressure and the piece order are unchanged, the run is marked `revived`.
   On false (skipped, error, no fill, timeout) nothing is cleared, the run settles as if "End run" was chosen and a "No video available right now." toast shows; there is no retry button.
3. End run: settles exactly like today (summary, XP, daily streak, run-break ad on the usual cadence).
4. The revive is saved in the run snapshot as an optional `revived` bool (absent = false) so a reload cannot offer a second one.
5. Mobile, plain web and GamePix builds never offer it (no rewarded ad exists there); their game-over flow is unchanged.

## Acceptance Criteria
- Board locked at >= 20 placements on a CrazyGames build: the card shows and the summary does not; no progress is written.
- Continue + ad finished: exactly the 6 lowest-tier camps are gone, `isGameOver` is false, `placements`, `score` and tools are unchanged, a second lock ends the run with no second offer.
- Ad not finished: no camps cleared; the run settles once and the summary shows.
- A second lock later in the same session (new run) shows no card. The default (Basic Launch) build never shows it.
- Runs with < 20 placements, restarted runs and snapshot reloads with `revived: true` never show the card; a reload of a pre-lock snapshot is unchanged.
- The card works with keyboard (Enter continues, Esc/R ends) and at 320px width.
- Rules, scoring, XP and Daily Camp sequence are unchanged for runs that never use it. lib/ strings are English ASCII.

## Constraints
- No new package, no new asset. The reward is never given without the SDK reporting a finished rewarded ad.
- Music and gameplay events stop during the ad like the run-break ad.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| Controller revive + snapshot | `lib/src/game/merge_camp_controller.dart` | `test/second_wind_test.dart` |
| Rewarded ad hook | `lib/src/platform/game_platform.dart`, `crazygames_platform.dart` | `test/second_wind_test.dart` (fake platform) |
| Offer card and settlement delay | `lib/src/game/merge_camp_screen.dart`, `lib/src/game/ui/second_wind_overlay.dart` | `test/second_wind_test.dart` |

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`, `tool/build_crazygames.sh`
- Effect on playtime is measured after upload (CrazyGames Engagement tab).
