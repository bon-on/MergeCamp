---
id: adr-supabase-result-submission
title: Submit measured results directly to the shared Supabase RPC
status: accepted
related_specs:
  - feature-post-game-leaderboard
---

# ADR: Shared leaderboard submission

## Context
The static game must submit a measured result without exposing a privileged server key or making connectivity part of gameplay.

## Decision
Use the shared Supabase publishable endpoint and submit_result RPC. Flutter owns the opt-in and name dialogs; the game supplies its measured score value. Network failure is non-fatal.

## Consequences
The feature works on web and mobile with one Flutter implementation. Public clients cannot provide strong anti-cheat guarantees, but players never type the result in the normal UI.
