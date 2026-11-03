---
id: adr-run-snapshot
title: Persist live runs and meta progress in one local envelope
status: accepted
related_specs:
  - feature-first-run-resume
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
