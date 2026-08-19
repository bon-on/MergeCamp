---
id: adr-static-web-shell-hub-link
title: Put game-hub navigation in the static web shell
status: accepted
related_specs:
  - feature-game-hub-navigation
---

# ADR: Static web-shell hub link

## Context
Each game is an independent GitHub Pages site, so navigation from the hub removes the hub UI. Browser history is not a reliable or discoverable return control, especially for an installed PWA.

## Decision
Place an always-visible, accessible link to https://bon-on.github.io/ in the top-right of web/index.html. Keep it above the Flutter surface and inside mobile safe areas without covering the top-left game title. Do not add this control to native builds.

## Consequences
- Players can return to game selection from every web game.
- The control is independent of Flutter state and browser history.
- Each game's web shell carries a small shared navigation style.
