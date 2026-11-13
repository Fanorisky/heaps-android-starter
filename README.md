# Neon Drift — a native Heaps Android starter

A complete small portrait arcade game made with Haxe and Heaps.io. Drag the ship left/right, dodge pink hazards, collect green energy, and survive 45 seconds. Three hits end the run. The game includes a title/tutorial, score and health, pause/resume, results, restart, and a saved personal best.

This project compiles **Haxe → HashLink/C → Android native libraries → APK**. SDLActivity hosts the OpenGL ES renderer. Gameplay runs as native compiled code. The game works offline.

## Download an APK

GitHub Actions builds both native ABIs on every push to `main`. Open [Build Android APK](https://github.com/Fanorisky/heaps-android-starter/actions/workflows/android.yml), select a successful run, and download `neon-drift-debug-apk` from Artifacts. Extract the ZIP and install `neon-drift-debug.apk` on an Android24+ device with GLES3. Tagged test builds are also available from [Releases](https://github.com/Fanorisky/heaps-android-starter/releases).

## Build on Linux

Tested toolchain:

- Haxe **4.3.6**, haxelib and Neko; Python **3.12+**, curl, unzip.
- JDK **17+** (the verified host uses JDK21).
- Android SDK platform **35**, build tools **34.0.0**, NDK **28.2.13676358**, CMake **3.30.3**.
- Gradle **8.11.1** and Android Gradle Plugin **8.6.1**, through the included wrapper.

On Debian, install the host tools with `apt install haxe neko curl python3 unzip openjdk-17-jdk` where those exact versions are available. Check `haxe --version`; use Haxe 4.3.6 for the verified configuration.

With Android command-line tools installed:

```sh
export ANDROID_HOME=/path/to/android-sdk
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  'platforms;android-35' 'build-tools;34.0.0' \
  'ndk;28.2.13676358' 'cmake;3.30.3' 'platform-tools'
# Accept Android SDK licenses as required by your SDK installation.

./scripts/build-apk.sh
```

The build script defaults to `/opt/android-sdk` when `ANDROID_HOME` is unset. The first build downloads pinned native source archives and Gradle/Maven dependencies. Once the sources and Gradle dependencies are cached, `./scripts/build-apk.sh --offline` builds without Maven downloads.

Output: **`dist/neon-drift-debug.apk`**, debug-signed for local installation, containing `arm64-v8a` and `x86_64` libraries. This is an Android24+ GLES3 development artifact. Configure your own release signing and complete physical-device testing before distribution as a production release.

```sh
"$ANDROID_HOME/platform-tools/adb" install -r dist/neon-drift-debug.apk
"$ANDROID_HOME/platform-tools/adb" shell am start -n io.heaps.neondrift/.GameActivity
```

## Develop and verify

```sh
./scripts/setup-toolchain.sh   # pinned dependencies, local haxelib mappings, explicit patches
./scripts/run-tests.sh         # deterministic model behavior tests
./scripts/generate-hlc.sh      # Haxe generates build/hlc/game.c
./scripts/build-apk.sh --offline
./scripts/verify-emulator.sh   # a connected, awake emulator; screenshots/report in dist/verification
```

`game.hxml` uses `-D no-compilation`: Haxe emits C and CMake performs the Android compilation. A separate HashLink VM or a nonexistent `hlc` executable is not required. Native sources remain in ignored `vendor/`; `.haxelib/` mappings affect this repository only.

To launch the emulator used during verification:

```sh
"$ANDROID_HOME/emulator/emulator" -avd pine-review -no-window -no-audio \
  -no-snapshot -gpu swiftshader_indirect
```

Use your own AVD name if different. The acceptance script installs the debug APK and exercises normal touch gameplay. It uses app phase logs and screenshots, and verifies the actual private save file survives force-stop/relaunch. It preserves an existing best score. Runtime evidence and its limits are described in `docs/verification/README.md`.

## Source map

- `src/game/GameModel.hx`: seeded spawning, steering, swept collisions, clock, score, health and transitions.
- `src/Main.hx`: Heaps graphics, 360×640 letterboxed touch UI and app-private atomic save writes.
- `app/src/main/java/io/heaps/neondrift/GameActivity.java`: SDL host/context, library load order.
- `app/src/main/cpp/CMakeLists.txt`: native runtime, renderer bindings and dependency build.
- `third_party/dependencies.lock.json`: exact source revisions and archive checksums; license copies alongside it.
- `patches/`: explicit compatibility changes required by the pinned native stack.

## Android integration details

Java loads `SDL2`, then `hl`, then `main`. HashLink's Android `JNI_OnLoad` lives in `libhl.so`; `HL_ANDROID_ACTIVITY` matches the Java class exposing `getContext()`. Generated game C includes HashLink's entry code, which exports `SDL_main` for SDL's native runner. `libmain.so` contains the game and native Heaps/SDL/format bindings, including the real mesh/format functions retained by Heaps' resource system.

Best scores use HashLink's `std/sys_special` native to resolve Android's internal files directory. Save data is versioned, bounded and checksummed; writes replace a temporary file atomically. Losing focus pauses the run and clears transient pointer input. Resuming requires an explicit tap.

Seven patches cover Heaps' newer optional GPU readback/timing APIs, Android GLES headers/unsupported desktop-only shader-storage binding, Android stack traces available on API24, modern Haxe SDL entry selection, ARM64 breakpoint instructions, the private-storage JNI signature, vec4 uniform counts, and SDL fullscreen window creation. GPU readback and elapsed-time query features requiring newer hlsdl deliberately report an unsupported-version error; this 2D game does not use them. See `patches/README.md` for the precise changes.

Native upstream sources emit some compiler/deprecation warnings. No unresolved application symbols are accepted. Physical ARM64 runtime behavior has not been established by an x86_64 emulator run.
