---
id: feature-run-goal
title: MergeCamp in-run goal line (next camp tier to build)
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
related_contracts:
  - contract-merge-camp-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
---

# Feature: in-run goal line

## Problem
CrazyGames Basic Launch scores playtime, and only about 31% of visitors reach 1 minute and 2.5% reach 10 minutes.
During a run the only goals on screen are the three missions. Nothing tells the player which camp to aim for next, so a run
feels like filling a board rather than climbing. The controller already had `goalLabel` / `goalProgress` getters
but they were never shown and their target never moved past the player's best camp.

## Scope
1. The controller exposes `goalTier`: the camp tier the player is climbing towards now,
   `max(4, highestTier + 1)` capped at the top tier (8). It only moves when a new best camp is built, so the bar never
   goes backwards (the unused time-based `goalTargetTier` is removed). `goalLabel` is "Build a <camp name>"
   (or "<camp name> built!" at the top tier) and `goalProgress` is `highestTier / goalTier` clamped to 0..1.
2. The board area shows one slim goal line (text + progress bar) at all times during a run:
   - wide layout: a panel between the level card and the missions;
   - narrow layout: a single line right above the board (24 px with its gap, the board shrinks to fit), only when the
     board stays at least 200 px with it; shorter windows (landscape phones) keep the bigger board and skip the line.
3. When the goal is reached (a new highest tier) the line moves to the next tier; the change is animated by the existing `AnimatedSwitcher` fade, no new asset or sound.
4. The line is hidden while guided practice is active (the practice caption owns the screen); on narrow layouts its row stays reserved, so the board does not move when practice ends.
5. Rules, scoring, spawn weights and XP are unchanged. lib/ strings are English ASCII.

## Acceptance Criteria
- A fresh run shows "Build a Scout Cabin" (tier 4 target) with a bar at 1/4 that grows when a higher camp is built.
- After the best camp reaches the goal tier the line shows the next tier; at tier 8 it reads "Star Observatory built!" with a full bar.
- The line is visible in wide layouts and narrow phones from 360x640 up without overflow; smaller narrow windows (320x568, 600x500) hide it because the board would drop below 200 px; the board stays square and playable.
- Hidden in guided practice. No effect on snapshots (derived from `highestTier` and placements).

## Constraints
- No new package, no new asset, no new persisted state.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| Goal getters | `lib/src/game/merge_camp_controller.dart` | `test/run_goal_test.dart` |
| Goal line widget and layout | `lib/src/game/ui/hud.dart`, `lib/src/game/ui/camp_layout.dart` | `test/run_goal_test.dart` (wide, narrow, 320px, practice) |

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`, `tool/build_crazygames.sh`
- Effect on playtime is measured after upload (CrazyGames Engagement tab).
