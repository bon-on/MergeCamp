---
id: adr-run-snapshot
title: Persist live runs and meta progress in one local envelope
status: accepted
related_specs:
  - feature-first-run-resume
  - feature-first-minute-rewards
  - feature-daily-camp
---

# ADR: Persist live runs and meta progress in one local envelope

## Context
Closing the tab mid-run lost the run. Meta progress (best score, album, XP, theme) is already one JSON value under `camp_progress_v1`, which CrazyGames also syncs through its data module. A separate key for the live run would open a window where the run is credited to XP but its snapshot still exists (or the reverse), so a reload could credit it twice.

## Decision
Extend the existing camp_progress_v1 JSON with an optional activeRun containing versioned controller and mission snapshots and guided-practice state. Keep legacy meta fields and ignore invalid snapshots. Restore only validated state before accepting input. Each action saves the complete current envelope through an ordered write queue. Finalization clears activeRun in the same write that applies XP/best, avoiding a cross-key double-credit window. A new run then writes its own snapshot.

The three visible preview pieces and all pressure/tool counters are restored. Future unseen random draws can differ after reload; no competitive daily seed mode is introduced. Snapshot validation is bounded and rejects impossible terminal/live board combinations. Local storage failure must not block gameplay.

Controller keeps pure merge rules and exposes a side-effect-free preview. Final-move mission fallback points are a dedicated operation, not a general ability to resurrect a terminal game.

## Consequences
- One write settles a run and removes its snapshot, so a run is credited at most once.
- Old saves without `activeRun` load unchanged; a bad snapshot is dropped and the meta fields are kept.
- Every placement or axe rewrites the whole envelope (a few KB); writes are serialized so an older envelope never lands after a newer one.
- Unseen future pieces are re-rolled after a reload; acceptable without a competitive daily mode.
- Input waits for the initial progress load, like it already waited for the tutorial flag.
- feature-first-minute-rewards keeps `activeRun` unchanged. The welcome run's mid-run level-up only writes meta fields (`welcomeRun`, `stickersSeen`, sticker slots, the one-time welcome bonus XP); the run's own XP is still credited once, in the write that clears `activeRun`.

## Addendum: Daily Camp marker (feature-daily-camp)
The controller snapshot may carry an optional `daily: {day, draws}` marker. On restore the date-seeded generator is recreated and advanced by `draws` (three previews plus one per placement), so the unseen pieces of a daily run are the same as in an uninterrupted run. A malformed marker rejects the whole run snapshot (the run is dropped, meta progress is kept). Snapshots without the marker restore as free-play runs, as before. The daily streak counters live in the same `camp_progress_v1` JSON, so they are written, credited and cloud-synced with the same envelope.

## Addendum: Second Wind marker (feature-second-wind)
The controller snapshot may carry an optional `revived: bool` (absent = false; a non-bool rejects the whole run snapshot). `revive()` is the only allowed way out of a terminal state: it is gated on `canRevive` (locked board, not yet revived, at least 20 placements), clears the six lowest camps and may run once per run. The "no resurrecting a terminal game" rule above otherwise still holds. While the Second Wind card is open the run is not settled and `activeRun` keeps the last pre-lock snapshot, so a reload replays the same forced lock and shows the card again; `revive()` itself draws no random pieces, so Daily `draws` stay valid. XP and best score are still credited once, in the write that clears `activeRun`.
