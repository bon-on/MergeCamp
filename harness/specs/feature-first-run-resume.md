---
id: feature-first-run-resume
title: First merge practice, fair rewards, resume and placement previews
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
  - adr-run-snapshot
related_contracts:
  - contract-merge-camp-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - harness-audit
---

# Feature spec: First merge practice, fair rewards, resume and placement previews

## Problem
The retention polish review found lost final-move mission rewards and opportunities to make the first run understandable and preserve unfinished play.

## Scope
- Final-move missions pay a 150-point fallback before the result is recorded. A terminal run remains terminal; other completed missions still pay an axe or the existing capped bonus.
- First-time players choosing Play after the explanation practice merging two preplaced tents with a third at a highlighted plot. Skip/Escape bypass practice. Help opened during play never resets the board.
- A first-time run starts with achievable fixed missions: one merge, six placements, build tier 3; later sets/runs use existing random missions.
- Save an active run after each placement/axe and restore it on reopening, including previews, score, tools, pressure counters, missions and practice state. Never credit an already-settled run again.
- Preview the full merge chain and affected plots on mouse hover or keyboard cursor without changing state. Touch keeps one-tap placement; guided practice remains usable on touch.
- Participation XP requires five placements and at least one merge. Score and mission XP are unchanged.

## Acceptance Criteria
- A mission on the terminal move adds its score fallback to summary, best and score XP; message matches the reward.
- Practice accepts only its highlighted placement, supports skipping, and yields an actual merge, discovery and first mission reward. It does not recur when opening Help.
- First-time missions do not depend on random chain/large-cluster objectives.
- Reloading a live run restores board, three upcoming pieces, axes, counters, mission progress and earned mission XP. Restart/game over atomically clears the old active snapshot while crediting the run once.
- Old camp_progress_v1 saves remain readable. Malformed run snapshots are rejected without losing valid meta progress or blocking play. Input waits for initial load in production; storage errors fall back safely.
- Preview agrees with real placement for normal, cluster and chain merges, does not consume randomness or mutate controller, and is absent for occupied plots/axe mode.
- Zero-merge restart farming gives no participation XP.
- Existing keyboard, audio, tutorial, ads and platform tests pass. Layout fits 1280x720, 1366x768, 390x844, 360x640 and 640x480.

## Constraints
No new dependencies, no external runtime requests, English ASCII lib strings, existing merge formula/spawn weights unchanged. This spec explicitly supersedes the old unconditional participation bonus and clarifies terminal rewards in retention-polish. Do not upload/publish as part of this task.

## Plan and check mapping
| Requirement | Owner / files | Verification |
|---|---|---|
| Controller snapshots, preview, terminal bonus, seeded practice | controller worker: controller + dedicated tests | controller unit tests |
| Mission snapshots/starter set, meta active-run envelope/XP | meta worker: meta files + dedicated tests | meta unit tests |
| Practice/resume integration, preview UI, serialized writes | coordinator: screen, UI, store, integration tests | widget/reload tests |
| Integration/release regression | coordinator | analyze, all VM/Chrome tests, portal/Pages builds |
| Acceptance review | independent reviewer | harness-review against 3b06145 |

## Acceptance test map
| Acceptance criterion | Tests |
|---|---|
| Terminal mission fallback in summary, best, score XP and message | `test/ui_screen_test.dart` (game over summary), `test/controller_resume_preview_test.dart` (final mission bonus) |
| Practice: only the highlighted plot, skip, real merge/discovery/first reward, not on Help | `test/first_run_resume_test.dart` (first Play, keyboard Enter, Skip, practice reload, storage errors), `test/how_to_play_test.dart` (held Enter) |
| Fixed first-time missions, random afterwards | `test/meta_resume_test.dart` (starter set), `test/first_run_resume_test.dart` (starter/returning players) |
| Reload restores board, pieces, axes, counters, missions, mission XP; restart/game over clears and credits once | `test/first_run_resume_test.dart` (reload, finished run), `test/controller_resume_preview_test.dart`, `test/meta_resume_test.dart` |
| Legacy saves, malformed snapshots, load gate, storage errors | `test/meta_resume_test.dart`, `test/first_run_resume_test.dart` (malformed, storage errors), `test/ui_screen_test.dart` (input waits for stored progress) |
| Preview agrees with placement, is pure, absent on occupied plots/axe mode | `test/controller_resume_preview_test.dart`, `test/first_run_resume_test.dart` (cursor and hover preview) |
| Zero-merge restarts give no participation XP | `test/meta_resume_test.dart`, `test/ui_screen_test.dart` (restart farming) |
| Existing keyboard/audio/tutorial/ads/platform tests; layouts | full `flutter test`, `test/ui_screen_test.dart` and `test/first_run_resume_test.dart` layout sizes |

Tests that depend on the screen inject `MemoryCampProgressStore`, because input now waits for stored progress (the default store reads shared preferences, which are not mocked in widget tests).

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /MergeCamp/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
