# Heaps Android

A reusable native Android host for **Heaps.io**, with Haxe APIs for audio, keyboard, vibration, sensors, display, device information and private storage. It follows Raymob's clone–configure–code workflow. Neon Drift and the Developer Features screen demonstrate the integration.

Haxe → HashLink/C → Android NDK → APK. Android7+ (API24), GLES3, ARM32/ARM64/x86_64. The sample works offline.

## Try the proof APK

Download the signed development APK from [Releases](https://github.com/Fanorisky/heaps-android-starter/releases). Open **Android Features** on the title screen to test music/SFX, volumes/mutes, keyboard input, haptics, optional sensors and display controls. **CHECKS** runs a real Heaps/OpenAL channel regression.

The proof app uses `io.heaps.android.proof` and installs alongside the original Neon Drift app. Its dedicated test certificate supports subsequent proof updates. These are development APKs; store/production signing is a separate user-owned process.

## Clone, configure, build

Requirements: Haxe4.3.6 + haxelib/Neko, Python3.12+, curl, JDK17+, Android SDK35/build-tools34.0.0, NDK28.2.13676358, CMake3.30.3. The Gradle8.11.1 wrapper and AGP8.6.1 are included.

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

Edit `gradle.properties` to choose the app name, application ID, version, orientation, immersive and keep-awake defaults. Java's host namespace stays `io.heaps.android`; configuring a new app does not rewrite Java sources. Application code is in `src/Main.hx`; reusable Haxe code is in `lib/heapsandroid/`.

Output: `dist/heaps-android-proof.apk`. Once source and Gradle dependencies are cached, append `--offline` to the build command. For an ephemeral debug build, use `--variant=debug`.

## Minimal application

```haxe
import heapsandroid.Android;
import heapsandroid.Audio;

class Main extends hxd.App {
    override function init() {
        Android.init();
        hxd.Res.initEmbed();
        if (Audio.init()) Audio.playMusic(hxd.Res.music, true);
    }

    override function dispose() {
        Android.shutdown();
        super.dispose();
    }

    static function main() {
        Android.prepare(); // configured SDL orientation before window creation
        new Main();
    }
}
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
Audio.playSfx(hxd.Res.pickup);
Haptics.vibrate(80);

if (Sensors.enable(heapsandroid.Sensors.SensorKind.Accelerometer)) {
    var sample = Sensors.sample(heapsandroid.Sensors.SensorKind.Accelerometer);
    if (sample != null) trace(sample.x);
}

var prefs = Preferences.open("settings", 1, function(_, _) return {});
prefs.setBool("vibration", true);
prefs.commit();
```

Modules above need their corresponding `heapsandroid.*` imports. The sample shows full integration, including Unicode scalar editing and legacy best-score serialization.

## Audio and assets

Native output uses **OpenAL Soft1.24.3/OpenSL ES** through HashLink's `hlopenal` bindings. OpenAL is a separate shared library, and imported extension-pointer globals are hidden to avoid symbol interposition. Device registration, focus generations and destruction share a lifetime gate; initialization and failed resume paths report failure instead of virtual playback success.

`assets/` contains an original PNG and seven original PCM16 WAVs. `scripts/generate-assets.sh --check` reproduces them byte-for-byte. Resources are embedded through Heaps and loaded using `hxd.Res`; no external storage permission is needed.

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

Pure tests cover the existing game plus platform policies, typed preferences, paths, Unicode editing and cues. Native host tests cover UTF16/UTF8 ingress, complete commits, cancellation/lifecycle queues, sensor packets and audio lifetime/generation state. Android checks use genuine Heaps channels and the actual platform APIs. Channel/AudioTrack progress proves playback processing; audible output and physical vibration still need a device listening/touch test.

The known Android30 emulator ARM32 NativeBridge failure reproduces with a minimal C setjmp/longjmp program. ARM32 compile/install checks remain valid; the user's Galaxy A10/Android11 established native execution of the original sample. We do not disable exception handling to mask that translated-emulator defect.

GitHub Actions builds ephemeral secret-free PR artifacts and stable signed `proof` artifacts on main/tags. Signing setup and public certificate are documented in [docs/signing](docs/signing/README.md). Current verification evidence is recorded in [docs/verification](docs/verification/README.md).

## Source layout

- `lib/heapsandroid/`: reusable Haxe APIs.
- `app/src/main/java/io/heaps/android/`: generic Android/SDL host and services.
- `app/src/main/cpp/platform/`: JNI/native platform state.
- `app/src/main/cpp/audio/`: audio gate and real OpenAL integration.
- `src/`: sample game and Developer Features screen.
- `tests/`, `scripts/`: reproducible host/device verification and builds.
- `patches/`: explicit upstream compatibility fixes, applied idempotently.

This is a native Android template integration, not a Haxelib-only replacement for Android build/host files. Clone the template to obtain those files; the Haxe module is isolated so it can also be incorporated into an existing Android host.
