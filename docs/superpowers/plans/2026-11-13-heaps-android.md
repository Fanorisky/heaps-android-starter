# Neon Drift Android implementation plan

> Use subagent-driven-development for the bounded game task; root owns native integration and verification.

**Goal:** A complete small Heaps game packaged and verified as a native Android APK.
**Architecture:** Haxe emits HashLink/C directly; SDLActivity hosts native GLES3 rendering. Model rules remain independent of rendering.
**Tech stack:** Haxe4.3.6, pinned Heaps, HashLink1.15, SDL2.32.10, Gradle8.11.1, AGP8.6.1, NDK28.2.13676358, CMake3.30.3.
**Spec:** ../specs/2026-11-13-heaps-android-design.md
**Canonical version:** 2, Advisor approved. Findings A001 direct C generation, A002 private atomic storage, A003 explicit JNI/SDL startup incorporated.

## Global constraints
Android24+, compileSdk35, GLES3, portrait, ARM64+x86_64 debug APK. No runtime Internet. No hidden native stubs or silent version bypasses. Work in the explicitly requested fresh repository; no remote publish.

## Tasks
- [ ] 1. Game executor: `src/game/GameModel.hx`, `src/Main.hx`, `tests/GameModelTest.hx`, `test.hxml`, `game.hxml`. Seeded model exposes phase, elapsed, remaining, ship, health, score, bestScore and entities; `start`, `setShipTargetX`, `update`, `pause`, `resume`, `restart`, `validateBestScore`. Test bounds, finite time, pause, damage/invulnerability, collections, deterministic spawning, win/loss, restart, saved-score validation. Main provides title, tutorial, HUD, pause, results and restart, scaled360x640 touch UI. Configure hxd.Save in private storage before loading via local `@:hlNative("std","sys_special")` binding with hl.Bytes argument/result; atomic temp+rename. Verify `haxe test.hxml`, `scripts/generate-hlc.sh`.
- [ ] 2. Root: pinned sources in ignored `vendor/`, repo-local haxelib mappings, exact archive SHA256 lock, licenses, setup/generation scripts. Haxe outputs `build/hlc/game.c` directly; no host hlc executable. Record any required compatibility patch under `patches/`.
- [ ] 3. Root: Gradle and native CMake. `io.heaps.neondrift.GameActivity` extends SDLActivity and exposes static getContext set before super.onCreate. Load SDL2,hl,main. libhl owns HashLink JNI_OnLoad/sys_android with matching HL_ANDROID_ACTIVITY; libmain generated C includes mobile hlc_main exporting SDL_main with SDL/fmt bindings. Build both ABIs; verify signature, native contents and entry symbols.
- [ ] 4. Root: emulator acceptance scripts and evidence. Install Android30x86_64; title/play/result/restart screenshots and touch controls, background/resume frozen timer, resize/touch mapping, best after force-stop/relaunch. Review code, resolve findings, document reproducible build and exact verification limits, commit locally.

## Review focus
Suspend must pause without a time jump; letterboxing preserves touch bounds; restart resets transient state; saves use private atomic replacement; JNI/load order/SDL_main and native symbols match without hidden stubs.

## Verification commands
`./scripts/run-tests.sh`, `./scripts/build-apk.sh`, `./scripts/verify-emulator.sh`, APK signature/native symbol inspection, `git status --short`.
