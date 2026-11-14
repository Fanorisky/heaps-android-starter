Run `haxe platform-test.hxml` from the repository root for pure lifecycle,
orientation/haptic normalization and exact 64-bit sensor decoding checks.
Run `bash tests/platform/run-native.sh` after dependency extraction/patching for
JNI UTF16-to-standard-UTF8 ingress (including pasted text/non-BMP), full
ASCII/Unicode/emoji UTF8 commits, malformed/truncated replacements,
cancel-during-poll generation rejection,
bounded callback queues, sensor registration/background preservation,
double-buffer coherence during concurrent publication and display-state checks.
ASan/UBSan are enabled by default; set `SANITIZE=0` on unsupported hosts.

`ApiCompile.hx` is compile-only against real Heaps, HashLink, hlsdl and hlopenal:

```
haxe -cp lib -cp tests/platform -lib heaps -lib hlsdl -lib hlopenal -lib format \
  -main ApiCompile -D hl-ver=1.15.0 -D android -D no-compilation \
  -hl /tmp/heaps-platform-hlc/platform.c
```

These host checks do not exercise Android/JNI, a real IME, sensors, vibration,
audio focus or applied window flags. APK/emulator/device checks establish those
behaviors; `ApiCompile` must not be executed as a hardware proof.

`StartupRegression.hx` is an Android-backed cold-start application. Build it
with the same library flags as `ApiCompile`, add `-D resourcesPath=res`, and
use `-main StartupRegression`. In `hxd.App.init`, before the first MainLoop tick,
it checks synchronized lifecycle state/callback ordering and creation of a real
music channel. It reports `ANDROID_STARTUP_TEST_PASS` or `FAIL` in Android logs.
Compilation alone does not establish these runtime checks.

Run `tests/platform/run-java.sh` for Android-free tests of the **production**
`NativeDispatch`, `SessionDispatch`, and `RouteTracker` helpers. The fixture
forces unavailable native libraries, verifies no callback is dispatched,
restarts the SDK using the retained Activity foreground/window snapshot, and
rejects old sensor/display/route/focus/cleanup identities. A blocked callback
holds the actual dispatch monitor while a concurrent stop attempts publication;
stop must wait until that callback finishes. Output device IDs are compared as
sets, so initial, duplicate and reordered callback batches do not signal a
route change. The native fixture also exercises the production `SessionEpoch`
second boundary with stale start/stop/callbacks and concurrent publication.
These tests establish dispatch and identity behavior; they do not emulate
Android hardware or prove a real Bluetooth/headset transition.

`Android.shutdown()` reversibly suspends SDK services and audio channels.
`Android.init()` creates a fresh native/Java epoch in the same live Activity;
subscriptions survive, and audio remains paused until explicit playback intent.
`Audio.shutdown()` remains the separate terminal audio-resource cleanup API.
`HeapsActivity.onDestroy()` terminally destroys its service owner. All our JNI
callbacks prepend a 64-bit epoch; native start publishes foreground/window
snapshots before SDK-active, and stop clears SDK-active before invalidation.
Output route generation is process-monotonic (saturating at signed Int max),
read through `Native.routeGeneration()` on the Haxe thread and never reset by
SDK shutdown/init. No Java callback invokes Haxe.

The library failure guard is initialized only after `SDLActivity.onCreate`
returns and requires `!SDLActivity.mBrokenLibraries`. The helper fixture tests
that exact production guard; a corrupt/missing-library APK additionally tests
SDL's real error Activity path and must report no `UnsatisfiedLinkError` from
our lifecycle callbacks. A host class-load/callback counter alone is not proof
that SDL's error dialog appears on a device.
