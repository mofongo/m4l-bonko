# Bonko Landing Page Design

**Date:** 2026-07-18
**Status:** Approved (user: "build it")

Single self-contained `docs/index.html` served by GitHub Pages from `main`.
No build step, no external assets (system font stack, inline CSS only).

Dark Ableton-native visual language: Live-style greys, cyan dial accent,
amber for the device's title-bar dot. Sections:

1. Hero — BONKO, tagline "Transient-triggered modulation for Ableton Live",
   buttons: Download Bonko.amxd (raw file on main) + View on GitHub.
2. CSS-drawn mock of the device panel (DETECT + 4 slots) with a looping
   animation: trigger LED blinks and a mapped-parameter bar spikes and
   decays in sync — illustrating transient → envelope → parameter.
3. "How it works" — three columns: Detect / Shape / Map.
4. Install — three steps.
5. Footer — GitHub link.

Constraint: GitHub Pages requires the repo to be public (or GitHub Pro);
enabling Pages is left to the user.
