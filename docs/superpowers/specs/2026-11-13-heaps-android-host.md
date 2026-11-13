# Heaps Android host: Raymob-style foundation

## Intent
The user wants a mature, reusable Heaps.io Android integration/template comparable to Raymob, with real audio and essential Android features. Neon Drift remains a working example and test harness. This milestone builds platform integration rather than new game progression.

The existing native proof works on the user's Galaxy A10/Android11. Preserve ARM32, ARM64 and x86_64 builds, Android24+, GLES3, the pinned HashLink1.15/SDL2 stack, and the existing example's rules. Sources remain in the same public repository. Continue GitHub Actions APK builds and test releases as previously authorized.

## Architecture and approach
Root recommendation: Heaps' normal `hxd.Res`/`hxd.snd` API with `hlopenal` backed by pinned OpenAL Soft, plus a separately reusable `heapsandroid` Haxe library and Android host. A custom SDL audio mixer would avoid another dependency but would expose a different sound API and make future Heaps games do more integration work. Raymob is a reference for capabilities, not code that must be copied unchanged.

Keep application code under `src/`, reusable Haxe modules under `lib/heapsandroid/`, and native platform code separate from game code. Provide a root haxelib.json with classPath `lib` and repository-local haxelib mapping. Native JNI services must never allocate or call Haxe objects from Android UI/sensor/audio callback threads. Queue events or native atomic state for consumption on the Heaps thread; OpenAL device operations must respect device lifetime. The immediate audio-pause gate must run natively even when SDL suspends the game thread, and resume only when foreground, audio focus and playback intent agree.

## First milestone capabilities
1. **Native audio:** packaged WAV sound effects and a looping music sample played through normal Heaps sound channels. Use OpenAL Soft's Android OpenSL ES output for the Android24+ baseline; do not claim Oboe/AAudio latency support in this milestone. Independent music/SFX volume and mute settings; preserve music position through pause. Android audio focus loss/background immediately silences playback and pauses the sample; gaining focus permits explicit resume. Dispose/release resources without an audio-device lifetime race. No microphone recording is needed.
2. **Bundled assets:** a small PNG and original generated WAV assets included through Heaps resource embedding. Include a reproducible asset-generation script, loader examples and licenses. Package OpenAL Soft as a separate shared library, with LGPL notices/source information, instead of statically folding it into the application. Asset loading works offline from the APK.
3. **Keyboard/text:** show/hide Android IME using SDL text-input facilities, expose committed Unicode input, and provide a small editable text example. Handle backspace, code points outside the BMP and hide/cancel on background. Avoid duplicating SDL's keyboard pipeline with a last-key-only Java API. The pinned SDL bridge currently keeps only the first four bytes of a text commit: preserve the whole commit through a documented patch or complete code-point events. Test multi-character/pasted ASCII, mixed Unicode and non-BMP input.
4. **Haptics:** availability query, bounded vibration duration, cancellation, and a persisted enable toggle. Use the normal VIBRATE permission; unavailable hardware returns unavailable without failing startup.
5. **Sensors:** accelerometer/gyroscope availability, enable/disable and latest XYZ/sample time. Optional hardware; missing gyroscope is shown clearly. Use normal game sampling rates and suspend listeners on background. No high-rate or dangerous sensor permissions are required.
6. **Display/device:** immersive and keep-screen-on controls, portrait/landscape configuration, safe inset/device/API/app ABI queries. Return actual app-supported ABI information so 64-bit hardware is not confused with a 64-bit Android app.
7. **Storage/lifecycle:** private files/cache directory access with validated relative paths and reusable atomic, versioned preferences for sound/haptics and the text example. Preserve the existing best-score save format in the Neon Drift sample. Provide main-thread lifecycle events and cleanup hooks for future applications.
8. **Configurable template:** editable app name, applicationId, versionCode/versionName, orientation and display defaults in gradle.properties. Use a fixed library/host namespace independent of applicationId so configuring a new game does not rewrite Java source. Validate configuration values and keep generated artifacts under ignored build/vendor paths.

## Demonstration
Add a compact Android Features screen to the example: music/SFX controls and test buttons, text input, vibration, optional sensor readings, display toggles, and device/app ABI information. The screen is intentionally a developer proof of platform APIs. The existing game demonstrates playback during normal button presses, pickups, hits and results; add minimal pure game event reporting where needed.

Use `Heaps Android Proof` / `io.heaps.android.proof` for the default integration demo, keeping the already-installed Neon Drift application separate. This avoids replacing its private data or requiring its old ephemeral CI debug signing key. Keep the current repository and game example.

## Signing and distribution
Maintain debug test APKs for this milestone. Generate a dedicated development signing keystore locally, keep its backup in ignored private signing files, and store it in repository-scoped GitHub Actions secrets (`HEAPS_ANDROID_TEST_KEYSTORE`, `HEAPS_ANDROID_TEST_STORE_PASSWORD`, `HEAPS_ANDROID_TEST_KEY_PASSWORD`, `HEAPS_ANDROID_TEST_KEY_ALIAS`). Use that identity for default-branch test APK builds; fail clearly when required signing inputs are missing rather than silently rotate the certificate. Fork PR checks may use an ephemeral local debug identity and must not claim upgrade compatibility. These are development builds; production/store signing remains a separately configured user-owned process. Do not commit signing keys or print secret values. Accepting this design includes setting up these test-only repository secrets. Verify certificate continuity across builds, without claiming the old v0.1.1 private key can be recovered.

## Public interfaces and boundaries
Expose focused Haxe modules for Audio, Keyboard, Haptics, Sensors, Display, Device, Storage and Lifecycle through `heapsandroid`. The implementation plan must specify exact signatures and ownership. Keep Java/Native host classes generic under `io.heaps.android`; configure HashLink's activity class consistently and update APK/emulator tooling to read the actual app ID/activity/library configuration rather than assume the original game package.

Normal Heaps audio calls must resolve to real OpenAL primitives. Link genuine implementations and preserve dependency licenses. Unsupported hardware/features return a clear status. Do not add success-returning dummy natives or broadly disable exception handling to accommodate translated ARM emulators.

## Verification and acceptance
- Existing game behavior tests continue to pass; new meaningful tests cover preferences validation/migration, Unicode edits, event emission and lifecycle state transitions.
- Compile/link/signature checks cover all three ABIs and the new native audio/platform symbols and dependencies.
- Assets have valid PNG/WAV structure, bounded PCM amplitude, and are present through the Heaps resource loader.
- On an Android emulator, verify normal gameplay plus Features controls, IME input, save persistence, focus/background behavior, sensor availability and native audio track/channel progress. Validate actual output samples where the environment permits; distinguish stream activity from listening on a physical speaker.
- Test app metadata customization without source mutation, missing optional hardware, and repeated lifecycle operations/resource cleanup.
- GitHub Actions produces the downloadable APK and signature evidence. Phone testing on the user's Galaxy A10 establishes audible output/haptics and physical ARM32 behavior. Keep the known emulator ARM32 setjmp/longjmp translation limitation explicit.

## Scope limits
No billing/ads, networking, recording/microphone access, camera, multiplayer, new campaign, or Play Store publishing in this milestone. No repo rename or unrelated refactoring. Sensor/keyboard/display APIs are included because the user explicitly cited Raymob's style of Android integration.

## Approval status
Builder review completed; no additional user decisions were required. User approved the full scope, including dedicated repository test-signing secrets, by replying "full".
