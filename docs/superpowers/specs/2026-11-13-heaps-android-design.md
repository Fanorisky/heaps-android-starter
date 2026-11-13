# Heaps Android proof: Neon Drift

## Intent
The user wants to prove a complete small Heaps.io game can become an Android APK, and explicitly requested making the game from scratch and initializing its own project folder. Work lives in `/root/heaps-android-starter`, initialized on `main`. Build and verify the playable artifact in this session; make the build reusable as a starter.

## Approach
Root decision: Haxe + Heaps -> HashLink/C -> Android NDK shared library, hosted by SDLActivity. This exercises native Heaps rendering on Android. A WebView with the JavaScript target would be easier but would establish a different deployment path. A HashLink bytecode VM in Android would add unnecessary runtime loading; ahead-of-time C works on ARM64 and x86_64.

Use pinned HashLink 1.15 (SDL2 bindings), SDL 2.32.10, installed Haxe 4.3.6 and a pinned Heaps commit. CMake builds native runtime and format dependencies. Gradle builds a debug-signed APK for Android 24+, with GLES3, portrait orientation and ARM64 + x86_64. No Internet permission or remote service is needed by the game.

## Game
Root decision: **Neon Drift**, a portrait arcade survival game. Drag left/right to steer a luminous ship, avoid falling obstacles and collect energy. A run lasts 45 seconds. Three collisions end a run; surviving wins. Include title/tutorial, score, health, pause/resume, win/loss results, restart, and persisted best score. Simple graphics are drawn with Heaps; no external artwork is required. Touch is primary; keyboard controls can help desktop debugging.

Logical playfield: 360 x 640, scaled to fit any portrait display. Render UI within this playfield. Never continue simulation while paused/backgrounded; reset transient pointer input when focus is lost. Cap simulation delta to avoid jumps after suspend. Restart must clear entities, score, timers and health. Accept only finite saved scores in a sensible integer range.

## Structure
`src/game/GameModel.hx` owns deterministic rules, no graphics dependency. `src/Main.hx` owns Heaps presentation and input. `tests/GameModelTest.hx` verifies rules using the Haxe interpreter. `app/` and native CMake host the generated C. `scripts/` installs pinned local dependencies, compiles Haxe, builds and smoke-tests the APK. `README.md` explains prerequisites, exact commands, native architecture and limitations. `dist/` contains the final APK and evidence, ignored by Git.

## Acceptance
- A real APK contains native ARM64 and x86_64 game libraries and no WebView game.
- It installs and launches on the available Android emulator, renders gameplay, accepts touch input, and reaches results/restart.
- Background/foreground preserves a paused run without a large time jump.
- Best score survives process restart.
- Reproducible commands and source are committed locally; no remote publishing.
- Report precisely what was verified. Emulator verification does not imply physical ARM64 device testing or Play Store release readiness.

## Verification
Behavior tests for movement bounds, time/delta, collectible/obstacle collisions, health, win/loss, pause, restart and invalid save data. Compile/build both ABIs. Verify APK signature and native contents. Install on emulator, exercise title -> play -> results -> restart, background/resume, inspect screenshot and logs. Preserve dependency licenses and pin versions.
