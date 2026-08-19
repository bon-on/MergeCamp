---
id: feature-post-game-leaderboard
title: Post-game opt-in leaderboard registration
status: active
owner: games
related_adrs:
  - adr-supabase-result-submission
related_contracts:
  - contract-post-game-leaderboard
required_evidence:
  - flutter-tests
  - harness-audit
---

# Feature: Post-game leaderboard registration

## Problem
Players should register a trustworthy game-produced result without typing the result themselves.

## Scope
- After a completed run, ask whether to register the result.
- If accepted, ask only for a 1-20 character player name.
- Submit merge-camp using metric score; ranking uses highest score.
- Keep gameplay available if the network is unavailable or registration is declined.

## Acceptance Criteria
- The prompt appears once per completed run.
- Declining or failing submission never blocks restart or continued play.
- The submitted numeric result comes from game state, not player input.
- Blank or oversized names are rejected.
- A successful or failed submission gives visible feedback.
- Flutter tests and harness audit pass.

## Constraints
- Submission is optional and is the only online dependency.
- Only the Supabase publishable key may ship in the client.
- Existing gameplay rules remain unchanged.

## Evidence
- flutter test
- harness audit

