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
Reserve a static navigation bar above the Flutter web surface in web/index.html and place an accessible, left-aligned link to https://bon-on.github.io/ inside it. Offset and resize the Flutter host by the bar height, including the mobile top safe area, so the control never overlays game content. Do not add this control to native builds.

## Consequences
- Players can return to game selection from every web game.
- The control is independent of Flutter state and browser history.
- Each game's web shell carries a small shared navigation style.
