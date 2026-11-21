---
id: feature-instant-first-run
title: MergeCamp first run starts at the guided merge without the How to play card
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
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

# Feature: instant first run

## Problem
On CrazyGames only 52% of visits reached "playing started" (`gameplayStart`) in Basic Launch (2026-11-13 snapshot).
`gameplayStart` fired only after a new player read a three-page How to play card (Next, Next, Play), so every
visitor had to read text before the first tap. CrazyGames favours games that are playable at once. The guided
practice merge already teaches placing and merging by doing, and the one-time tool hints (feature-tool-hints)
explain Shift and Trail Axe when they first matter.

## Scope
1. A first run (tutorial flag not set) opens no card. Once the flag check and stored progress have loaded, the guided
   practice merge starts at once (same board, caption and Skip practice as before) together with the starter missions,
   and `gameplayStart()` fires.
2. The `tutorial_seen_v1` flag is written when the first run starts, so a reload never shows the card either;
   a reload mid-practice restores the practice from the run snapshot as before.
3. The `?` button still opens the three-step card at step 1 for anyone; closing it (Skip, Play, Escape) only closes it.
4. Returning players (flag set) are unchanged. Storage failures never block play (read failure = first run, write failure ignored).
5. Supersedes the first-run part of `feature-how-to-play-tutorial` (the card is no longer shown automatically).

## Acceptance Criteria
- Fresh install: no card; the practice caption shows, the flag is stored once, `gameplayStart` fires once.
- Slow progress load: practice and starter missions start when it arrives; input is blocked until then.
- `?` opens the card, blocks game input, reports gameplayStop/Start on open/close without doubles.
- Skip practice, R and Escape on the practice still skip it and keep the starter missions.
- Wide and narrow layouts unchanged; lib/ strings English ASCII.

## Constraints
- No new package, asset or persisted key.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| First-run start without card | `lib/src/game/merge_camp_screen.dart` | `test/how_to_play_test.dart`, `test/first_run_resume_test.dart` |
| Practice/missions/coach still work | same | `test/first_minute_polish_test.dart`, `test/first_minute_rewards_test.dart`, `test/camp_shift_test.dart` |

## Evidence
- `flutter analyze`, `flutter test`, `tool/build_crazygames.sh`
- Effect is measured after upload (CrazyGames "playing started" share of visits).
