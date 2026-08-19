---
id: feature-game-hub-navigation
title: Always-visible return link to the game hub
status: active
owner: games
related_adrs:
  - adr-static-web-shell-hub-link
related_contracts:
  - contract-game-hub-navigation
required_evidence:
  - flutter-tests
  - flutter-web-build
  - harness-audit
---

# Feature: Return to the game hub

## Problem
Players who launch a game from the Bon-on dashboard need an explicit way to return to the game selection screen.

## Scope
- Show an always-visible game-list link over the web game.
- Navigate directly to https://bon-on.github.io/ without relying on browser history.
- Keep native mobile behavior and game rules unchanged.

## Acceptance Criteria
- The web entry point contains an accessible link to the Bon-on game hub.
- The link remains visible above the Flutter surface and respects mobile safe areas.
- Flutter tests, web build, and harness audit pass.

## Constraints
- Implement navigation in the static web shell only.
- Do not add a runtime dependency or modify gameplay.

## Evidence
- flutter test
- flutter build web --release
- harness audit
