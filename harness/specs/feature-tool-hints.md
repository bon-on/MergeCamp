---
id: feature-tool-hints
title: MergeCamp one-time hints for Shift and Trail Axe
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

# Feature: one-time tool hints

## Problem
The How to play card has one text line about Shift and Trail Axe, and the practice merge teaches neither.
Players first meet Shift as a toast ("Shift earned!") that disappears in seconds and Trail Axe as a button.
Tools lengthen runs (the playtime benchmark CrazyGames rejected MergeCamp on), but players who never learn them lose boards they could have saved.

## Scope
1. Shift hint: the first time the player holds a Shift (earned by a placement or by a mission), a caption bar over the board says
   "Shift: tap the button, pick a camp, then a glowing cell to move it."
2. Trail Axe hint: the first time the board reaches the danger level (`dangerOccupied`) while the player holds a Trail Axe,
   a caption bar says "Board filling up? Tap Trail Axe, then a camp to clear it."
3. Each hint shows once per device (saved in `shared_preferences` key `tool_hints_v1`, a bit set: 1 Shift, 2 Axe; CrazyGames syncs it like the other keys).
   It is marked seen when it first shows, so a reload never shows it again.
4. A hint disappears when the 4th placement after it is made, when its tool is used, at game over and on restart. It is only hidden while shift/axe mode is on (it comes back if the player cancels the mode).
5. Only one hint at a time (Shift first). Never chosen during guided practice or while the practice coach line is up. On narrow screens the toast list sits above the hint bar.
6. No rules, scoring, XP or save format change.

## Acceptance Criteria
- A new device earning its first Shift sees the Shift hint; the next earn shows none. Same for Trail Axe at the danger level.
- The hint is hidden while the player is in shift/axe mode, after using the tool, after 4 placements and at game over.
- Storage failure shows no hint and never blocks play. lib/ strings are English ASCII.
- The bar does not block taps on the bottom row (like the coach hint) and fits 320px width.

## Constraints
- No new package or asset.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| Store | `lib/src/game/tool_hints.dart` | `test/tool_hints_test.dart` |
| Show/hide rules | `lib/src/game/merge_camp_screen.dart`, `lib/src/game/ui/camp_layout.dart` | `test/tool_hints_test.dart` |

## Evidence
- `flutter analyze`, `flutter test`, builds. Effect is judged by Engagement metrics after the next launch.
