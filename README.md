# GameBase Android

An empty **[deepnight/gameBase](https://github.com/deepnight/gameBase)** foundation on a native **Heaps.io** Android host. GameBase provides the App/Game/process/entity/camera/UI structure, CastleDB constants, LDtk world and Aseprite assets. The reusable Android APIs cover audio, keyboard, vibration, sensors, display, device information and private storage.

Haxe → HashLink/C → Android NDK → APK. Android7+ (API24), GLES3, ARM32/ARM64/x86_64. The sample works offline.

## Build the foundation APK

The app starts an empty GameBase world. Open **Android Features** to test music/SFX, volumes/mutes, keyboard input, haptics, optional sensors and display controls. **CHECKS** runs a real Heaps/OpenAL channel regression. Gameplay remains paused after background/focus loss until **RESUME GAME** is pressed.

The app retains `io.heaps.android.proof` and the dedicated proof certificate for signed updates. Local debug builds have a different certificate. Existing v0.2.x [Releases](https://github.com/Fanorisky/heaps-android-starter/releases) contain the previous application; build this revision or download its Actions artifact for GameBase. These are development APKs; store/production signing is a separate user-owned process.

## Clone, configure, build

Requirements: Haxe4.3.6 + haxelib/Neko, Node.js, Python3.12+, curl, JDK17+, Android SDK35/build-tools34.0.0, NDK28.2.13676358, CMake3.30.3. The Gradle8.11.1 wrapper and AGP8.6.1 are included.

```sh
git clone https://github.com/Fanorisky/heaps-android-starter.git
cd heaps-android-starter
export ANDROID_HOME=/path/to/android-sdk
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  'platforms;android-35' 'build-tools;34.0.0' \
  'ndk;28.2.13676358' 'cmake;3.30.3' 'platform-tools'

./scripts/setup-toolchain.sh
python3 scripts/setup-test-signing.py
./scripts/build-apk.sh --variant=proof
```

Edit `gradle.properties` to choose the app name, application ID, version, orientation, immersive and keep-awake defaults. Java's host namespace stays `io.heaps.android`; configuring a new app does not rewrite Java sources. Game code is in `src/game/`; reusable Android code is in `lib/heapsandroid/`.

Output: `dist/heaps-android-proof.apk`. Once source and Gradle dependencies are cached, append `--offline` to the build command. For an ephemeral debug build, use `--variant=debug`.

## Build your game

`src/game/Boot.hx` prepares Android before window creation and drives `dn.Process.updateAll`. `App.hx` initializes resources and starts `new Game()`. Add entities in `Game.startLevel`, extend `Entity`, and edit the empty LDtk world in `res/levels/sampleWorld.ldtk`. GameBase's platformer player and the previous arcade game have been removed.

Fonts, the sprite atlas, constants and levels live in `res/`. `src/game/assets/` contains the typed CastleDB/LDtk/Aseprite accessors. `src/demo/` is the separate Android proof UI; it scales independently of the game viewport and locks game input while open.

GameBase master is pinned at `a7af1d70dbbf62d7fc09cb05431ced606e0ed809`. The repository uses its existing patched Heaps/HashLink alongside pinned GameBase libraries. Use `scripts/setup-toolchain.sh`; upstream's `setup.hxml` installs floating revisions and replaces those mappings. Import details and Android adaptations are in [third_party/gamebase.md](third_party/gamebase.md).

## Android SDK use

Android startup and shutdown are already handled by Boot. Application code can use the same normal Heaps sound resources:

```haxe
import heapsandroid.Android;
import heapsandroid.Audio;

// Audio resources below are the Android proof screen's test fixtures.
if (Audio.init()) Audio.playMusic(hxd.Res.android.music, true);
```

`Android.init()` installs a main-loop pump before Heaps sound updates. Native foreground/audio-focus callbacks silence the device immediately; Haxe events and channel changes stay on the Heaps thread. Returning to the app leaves playback paused until `Audio.resume()` or an explicit play action.

## API overview

| Module | Functions and behavior |
|---|---|
| `Audio` | Normal Heaps Sound/Channel resources; music and SFX buses, volume/mute, explicit pause/resume, nullable playback on failure. |
| `Keyboard` | Show/hide Android IME; complete committed Unicode arrives through normal `hxd.Window` text events. |
| `Haptics` | Availability, bounded vibration, cancellation and enable toggle. |
| `Sensors` | Optional accelerometer/gyroscope, enable/disable, latest XYZ and exact nanosecond timestamp; listeners suspend in background. |
| `Display` | Applied immersive/keep-awake state and safe insets. |
| `Device` | SDK, model, supported ABIs and actual compiled app ABI. |
| `Storage` | Validated relative paths in private files/cache; atomic writes and nullable reads. |
| `Preferences` | Versioned JSON, typed fallback, migrations, atomic commit; future schemas are preserved. |
| `Lifecycle` | Main-thread foreground/background/window-focus subscriptions. AudioManager focus is handled independently. |

Examples:

```haxe
Audio.sfxVolume = 0.75;
Audio.playSfx(hxd.Res.android.pickup);
Haptics.vibrate(80);

if (Sensors.enable(heapsandroid.Sensors.SensorKind.Accelerometer)) {
    var sample = Sensors.sample(heapsandroid.Sensors.SensorKind.Accelerometer);
    if (sample != null) trace(sample.x);
}

var prefs = Preferences.open("settings", 1, function(_, _) return {});
prefs.setBool("vibration", true);
prefs.commit();
```

Modules above need their corresponding `heapsandroid.*` imports. The proof screen shows Unicode scalar editing and persisted settings independently of gameplay.

## Audio and assets

Native output uses **OpenAL Soft1.24.3/OpenSL ES** through HashLink's `hlopenal` bindings. OpenAL is a separate shared library, and imported extension-pointer globals are hidden to avoid symbol interposition. Device registration, focus generations and destruction share a lifetime gate; initialization and failed resume paths report failure instead of virtual playback success.

`res/android/` contains seven original PCM16 WAV test fixtures. `scripts/generate-assets.sh --check` reproduces them byte-for-byte. GameBase's fonts, Aseprite atlas and LDtk foundation are imported with its MIT notice. Resources are embedded through Heaps and loaded using `hxd.Res`; no external storage permission is needed. Android builds use embedded resources even with `-debug`.

OpenAL Soft's LGPL notice/source information and other dependency licenses are in `third_party/`. Source archives, revisions and SHA256 checksums are locked in `third_party/dependencies.lock.json`.

## Verify and develop

```sh
./scripts/test-pure.sh
./scripts/test-native-host.sh
./scripts/generate-assets.sh --check
./scripts/generate-hlc.sh
./scripts/verify-apk.sh dist/heaps-android-proof.apk
./scripts/test-hl-audio.sh dist/heaps-android-proof.apk emulator-5554
./scripts/test-android.sh dist/heaps-android-proof.apk emulator-5554
```

Pure tests cover GameBase pause ownership plus platform policies, typed preferences, paths and Unicode editing. Native host tests cover UTF16/UTF8 ingress, complete commits, cancellation/lifecycle queues, sensor packets and audio lifetime/generation state. Android checks use genuine Heaps channels and the actual platform APIs. Channel/AudioTrack progress proves playback processing; audible output and physical vibration still need a device listening/touch test.

The known Android30 emulator ARM32 NativeBridge failure reproduces with a minimal C setjmp/longjmp program. ARM32 compile/install checks remain valid; the user's Galaxy A10/Android11 established native execution of the original sample. We do not disable exception handling to mask that translated-emulator defect.

GitHub Actions builds ephemeral secret-free PR artifacts and stable signed `proof` artifacts on main/tags. Signing setup and public certificate are documented in [docs/signing](docs/signing/README.md). Current verification evidence is recorded in [docs/verification](docs/verification/README.md).

## Source layout

- `lib/heapsandroid/`: reusable Haxe APIs.
- `app/src/main/java/io/heaps/android/`: generic Android/SDL host and services.
- `app/src/main/cpp/platform/`: JNI/native platform state.
- `app/src/main/cpp/audio/`: audio gate and real OpenAL integration.
- `src/game/`: GameBase application, entities, camera, levels, UI and tools.
- `src/demo/`: independent Android Features screen and game session pause policy.
- `res/`: embedded GameBase resources and Android audio fixtures.
- `tests/`, `scripts/`: reproducible host/device verification and builds.
- `patches/`: explicit upstream compatibility fixes, applied idempotently.

This is a native Android template integration, not a Haxelib-only replacement for Android build/host files. Clone the template to obtain those files; the Haxe module is isolated so it can also be incorporated into an existing Android host.

## Reliability and recovery

`Android.shutdown()` stops the SDK session and freezes channels while preserving their Manager, device and positions. `Android.init()` can restart the session in the same live Activity; it does not restore playback intent. Activity destruction remains terminal. `Audio.shutdown()` explicitly releases audio resources.

The native audio gate requires SDK active, Activity foreground, window focus, AudioManager focus and explicit playback intent. Any loss pauses playback; foreground/focus gains do not resume it. Raw `hxd.Res.sound.play()` channels are guarded too, including muted/virtual channels and fades. Raw play during a stopped/background/unfocused session or focus denial returns a paused channel; eligible playback without genuine output throws an explicit unavailable error. Wrapper methods return null on denied/unavailable playback.

`Audio.error` reports device/failure state. `Audio.recover()` makes one genuine device/context/Manager recreation attempt, releases **all old raw and wrapper channels**, and returns with fresh audio paused. Replay resources explicitly afterward. Recovery does not grant focus or revive stale handles. Route subscribers run on the Haxe thread:

```haxe
var unsubscribe = Audio.subscribeRouteChanges(function(generation) {
    trace('Audio route changed: ' + generation);
    // Decide when to recover/resume and replay; no implicit playback.
});
```

See [patch maintenance](patches/README.md) and the [physical-device test matrix](docs/verification/physical-device-matrix.md). Pinned build reproducibility does not establish compatibility with arbitrary future engine revisions. Bluetooth audibility, latency and battery performance remain measured-device work, not claims derived from CI.
