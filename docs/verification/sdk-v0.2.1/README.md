# SDK reliability v0.2.1

[Actions run43568107134](https://github.com/Fanorisky/heaps-android-starter/actions/runs/43568107134) passed for ed8c762. The downloaded three-ABI artifact passed certificate/native checks and the full Android30 x86_64 reliability scenario as an update of the existing proof app.

Verified:
- Pure game/platform/preferences/text/pause-policy tests; ASan/UBSan native gate/session tests; production Java dispatch fixture.
- Patched real Heaps CPU fade/Manager-disposal regressions, and fresh/idempotent/published-v0.2/incompatible patch matrix.
- Real Heaps/OpenAL wrapped/raw audible and muted/virtual channels freeze beyond sample duration; user pause and fade callbacks remain frozen; explicit resume/replay progresses.
- Real SDK stop/restart in the same Activity preserves channels and returns with no restored intent.
- Ten real HOME/foreground cycles assert independent native background snapshots (audio non-running, foreground bit0, no readable sensor samples/text input) plus last foreground-frame channel positions, requested user pause and recovery.
- Recovery invalidates old channels and leaves a genuinely new Manager/device paused, followed by explicit replay.
- Local missing-library Android fixture retained the error path without JNI lifecycle crash.
- Separate local actual ALC-error fixture froze processed-source buffers, rejected false playback, safely recovered from a route subscriber and resumed only after explicit recreation/replay. Fault injectors are absent from the default proof artifact.
- The dedicated test certificate and applicationId are unchanged; private preferences survive update/process restart.

APK SHA256:d95a556c5f7525a89de1c8338c35502306952cd7d2a8cf44d6560b1677777d6f.

This evidence is not a physical speaker/Bluetooth/headset/latency/battery benchmark. Those measurements and broader ARM device coverage remain in the [physical matrix](../physical-device-matrix.md). The ARM32 translated emulator's known setjmp issue is not bypassed by disabling exceptions.
