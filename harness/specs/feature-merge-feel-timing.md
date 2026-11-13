---
id: feature-merge-feel-timing
title: Faster merge presentation timing
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
  - adr-merge-camp-crazygames-web
related_contracts:
  - contract-merge-camp-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - harness-audit
---

# Feature spec: Faster merge presentation timing

## Problem
Players on phones still report a small delay when camps merge. Rules apply
instantly, but the merged tier only appears when the absorbed tiles land:
110 ms first flight + 200 ms flight = 310 ms after the tap, plus 220 ms for
every further chain step. On a slow phone frame these add to a visible lag.
`feature-mobile-perf` already cut frame cost; real-device frame time is
still unmeasured.

## Scope
- Shorten the board effect timeline (`FxTiming`): drop 180 -> 140 ms, first
  flight 110 -> 70, chain stagger 220 -> 150, flight 200 -> 140, pop
  260 -> 200, particles 650 -> 550, popup 950 -> 800, removal 360 -> 300.
  A single merge now lands at 210 ms (was 310) and a x3 chain at 510 ms
  (was 750).
- Keep order, easing, art, particles, points, rules, sounds and layout
  unchanged. Effects stay one-shot and never block input.

## Acceptance Criteria
- A single merge's new tier is on screen within 220 ms of the tap and a
  chain step adds at most 150 ms.
- Placement, merge and axe removal events still finish and clear the hidden
  cells (no tile stays covered after the timeline ends).
- Existing tests pass; board and score results are identical to before.

## Constraints
- No new dependencies, no rule or score change, ASCII lib strings.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /MergeCamp/`, `tool/build_crazygames.sh`
- Real-device feel is checked by the player; no device frame time is claimed.
