---
id: feature-large-screen-scale
title: MergeCamp side panels grow with fullscreen and big windows
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
  - crazygames-web-build
  - harness-audit
---

# Feature: large screen side panels

## Problem
In the wide layout the board grows with the window but the side panels (score, next, tools, missions) stop at
300 px wide and keep their design size. In fullscreen (1920x1080) the board is about 900 px while the panels and their
text look tiny next to it, which reads as unpolished on CrazyGames, where reviewers and players use fullscreen.

## Scope
1. `wideSideScaleFor(height) = clamp(height / 720, 1, 1.5)`. The side column width limit becomes `300 * scale`, and the
   panels are laid out at `max(side / scale, 270)` and fitted into the column (contain), so they grow up to 1.5x.
2. Windows up to 720 px tall are unchanged (the panels still only scale down on small screens).
3. The board keeps its own sizing from the remaining width and height. Because the side columns take more width, the
   board can be up to about 5% smaller than before on windows taller than 720 px (1366x768: 578 -> 552 px,
   1920x1080: 856 -> 816 px); this is the intended trade-off for readable panels. Narrow layout unchanged.

## Acceptance Criteria
- 1920x1080: the side panels render at least 1.3x their 1280x720 size; the board stays at least 700 px; no overflow.
- 1280x720, 1100x620 and phones: unchanged (same board width and panel size).

## Constraints
- No new package or asset.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| Side scale | `lib/src/game/ui/camp_layout.dart` | `test/large_screen_scale_test.dart` |
