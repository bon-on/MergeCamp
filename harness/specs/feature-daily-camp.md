---
id: feature-daily-camp
title: Daily Camp with a streak
status: active
owner: games
related_adrs:
  - adr-merge-camp-flutter-foundation
  - adr-run-snapshot
  - adr-merge-camp-crazygames-web
related_contracts:
  - contract-merge-camp-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - harness-audit
---

# Feature spec: Daily Camp with a streak

## Problem
CrazyGames Basic Launch (2026-11-06..12) measured D1 retention of 1.44% on
desktop and 0.00% on mobile, and average playtime of 5m01 / 4m30. MergeCamp has
levels, stickers, themes and per-run missions, but nothing that gives a
player a reason to come back tomorrow.

## Scope
- **Daily Camp**: one shared run per local calendar date. Its tile sequence is
  seeded by the date, so every player gets the same pieces in the same order
  (the board state still depends on the player's placements). Rules, merge
  formula, spawn weights, axes and missions are the normal ones.
- The date seed uses a small deterministic generator (xorshift32) instead of
  `dart:math` `Random(seed)`, which is not guaranteed to match between the
  Dart VM and the web.
- Retry: restarting a Daily Camp run replays the same sequence. Free play is
  a normal run with a random sequence and stays the default on launch.
- **Streak** (same rules as the NonoGrid daily): a Daily Camp run that counts
  (at least five placements and one merge, same bar as participation XP)
  extends the streak when it is the first counted run of that day. A missed
  day is forgiven once; the grace refills after seven rewarded days. A clock
  set before the last rewarded day never breaks the streak and gives no
  reward.
- **Reward**: a rewarded daily adds `40 + 10 * min(streak - 1, 4)` XP (40-80) to
  that run's XP. Normal run XP, missions and stickers are unchanged.
- The best Daily Camp score of today is saved; the run summary shows it,
  the streak, the bonus and a "tomorrow" line (streak N+1 and its bonus).
- Entry: a header button (Daily camp) starts or resumes today's run. It shows
  a dot while today is not rewarded yet. The summary of a daily run offers
  Try again (same sequence) and Free play.
- Saved data: optional `daily` object in `camp_progress_v1`
  (`lastDay`, `streak`, `best`, `graceReady`, `refillLeft`, `total`,
  `bestDay`, `bestScore`). Old saves load without it. The run snapshot gets an
  optional `daily: {day, draws}` marker so a reload resumes the same
  sequence. Cloud save needs no change: it syncs the same JSON.

## Acceptance Criteria
- Two controllers started for the same day deal the same pieces after the same
  placements; different days differ. The sequence is identical on VM and web
  (only 32-bit shifts and xors).
- The first counted daily run of a day extends the streak and pays the bonus;
  a second counted run of that day pays nothing and does not change the
  streak. A run below the participation bar neither counts nor breaks it.
- Gap of one missed day keeps the streak once (grace) and starts a refill;
  a longer gap resets it to 1. Clock set back: no reward, streak kept.
- Reloading a saved daily run restores the board and continues the same
  piece sequence; a snapshot with a malformed `daily` marker is rejected
  without losing the rest of the save. Old saves and runs without `daily`
  still restore.
- Free play, guided practice, missions, stickers, themes and cloud-save
  merge behave as before.
- The header button and summary actions fit 1280x720, 1366x768, 390x844,
  360x640 and 640x480 without overflow.

## Constraints
- No new dependencies, no network, ASCII lib strings, no change to merge
  rules or spawn weights.
- Today comes from an injectable clock so tests do not depend on the date.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /MergeCamp/`, `tool/build_crazygames.sh`
- Whether this raises D1 retention is unknown until it is shipped and
  measured on the portal.
