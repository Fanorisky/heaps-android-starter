# GameBase Foundation Implementation Plan

**Goal:** Replace Neon Drift with an empty deepnight/gameBase application that uses the existing Android SDK host.

**Architecture:** Import GameBase application sources and resources with narrowly documented Android adaptations. Preserve the native host and SDK fixtures; isolate the Features overlay from gameplay.

**Tech Stack:** Haxe 4.3.6, Heaps, GameBase, deepnightLibs, CastleDB, LDtk, Aseprite, HashLink/C and Android NDK.

**Spec:** ../specs/2026-11-14-gamebase-design.md

## Global Constraints

- GameBase revision a7af1d70dbbf62d7fc09cb05431ced606e0ed809; Android API24+, GLES3, ARM32/ARM64/x86_64.
- Keep patched Heaps/HashLink and the proof application ID/certificate.
- No Neon Drift gameplay, score handling or ship artwork.
- Android uses embedded resources and private storage; background/focus loss does not restore playback intent.

## Tasks

- [x] Pin GameBase's Haxe libraries, register them repository-locally and preserve dependency notices. Compile a real GameBase HLC smoke target to expose compatibility failures before adapting sources.
- [x] Import GameBase sources/resources, remove sample players and arcade-specific sources/tests, start an empty world and add Android lifecycle/private crash reporting adaptations. Keep Boot as the native entry point.
- [x] Preserve SDK Features as a scaled independent overlay with explicit pause/resume and cleanup. Move WAV fixtures to res/android and update resource references.
- [x] Update build metadata, asset generation, automation and README. Separate historical verification from evidence for this new app.
- [x] Run pure/Java/sanitized native/patch/asset regressions and native HLC compilation. Install the SDK and build/verify the three-ABI APK when available; document exact limitations. Inspect final diff and commit locally on feat/gamebase-foundation.
