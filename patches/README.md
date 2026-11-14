# Patch ownership and upgrade checks

All native sources are checksum-pinned. A patch is a maintained compatibility change; a passing old build does not establish compatibility with a newer upstream revision.

| Patch | Exact source revision | Target files | Reason | Regression owner | Upstream status |
|---|---|---|---|---|---|
| 001-heaps-hlsdl-version-guards.patch | heaps@3a970d27505131d00b2efd912511a1de094b374a | heaps/h3d/impl/GlDriver.hx | Older hlsdl optional GPU APIs | HLC generation + Android render | local; upstream submission unverified |
| 002-hashlink-android-native.patch | hashlink@742581569d4052babac359658e443e42c7c3e0c7 | hashlink/libs/sdl/gl.c, hashlink/src/hlc_main.c | Android GLES/stack trace compatibility | All ABI compile + native startup | local; upstream submission unverified |
| 003-hashlink-hlc-sdl-entry.patch | hashlink@742581569d4052babac359658e443e42c7c3e0c7 | hashlink/src/hlc_main.c | Modern HLC SDL entry selection | APK SDL_main symbol gate | local; upstream submission unverified |
| 004-hashlink-arm64-breakpoint.patch | hashlink@742581569d4052babac359658e443e42c7c3e0c7 | hashlink/src/hl.h | ARM64 breakpoint instruction | All ABI native compile | local; upstream submission unverified |
| 005-hashlink-private-storage-jni.patch | hashlink@742581569d4052babac359658e443e42c7c3e0c7 | hashlink/src/std/sys_android.c | Android private storage JNI signature | Android private preferences tests | local; upstream submission unverified |
| 006-heaps-vec4-uniform-count.patch | heaps@3a970d27505131d00b2efd912511a1de094b374a | heaps/h3d/impl/GlDriver.hx | Correct vec4 uniform count | Visible renderer + ABI build | local; upstream submission unverified |
| 007-hashlink-android-fullscreen.patch | hashlink@742581569d4052babac359658e443e42c7c3e0c7 | hashlink/libs/sdl/sdl.c | Android fullscreen creation | Android display flags | local; upstream submission unverified |
| 008-hashlink-android-arm32-breakpoint.patch | hashlink@742581569d4052babac359658e443e42c7c3e0c7 | hashlink/src/hl.h | ARM32 breakpoint dispatch | ARM32 compile/install evidence | local; upstream submission unverified |
| 009-hashlink-sdl-complete-text.patch | hashlink@742581569d4052babac359658e443e42c7c3e0c7 | hashlink/libs/sdl/sdl.c, hashlink/libs/sdl/utf8_packet.h | Complete/cancellable UTF8 text events | Platform native UTF8/cancel regressions | local; upstream submission unverified |
| 010-hashlink-openal-device-lifetime.patch | hashlink@742581569d4052babac359658e443e42c7c3e0c7 | hashlink/libs/openal/openal.c | OpenAL device lifetime close integration | Audio native lifetime tests | local; upstream submission unverified |
| 011-heaps-openal-checked-construction.patch | heaps@3a970d27505131d00b2efd912511a1de094b374a | heaps/hxd/snd/openal/Driver.hx | Checked OpenAL construction/disposal | AudioRegression partial constructor test | local; upstream submission unverified |
| 012-heaps-audio-manager-construction-cleanup.patch | heaps@3a970d27505131d00b2efd912511a1de094b374a | heaps/hxd/snd/Manager.hx | Manager partial allocation cleanup | AudioRegression source-exhaustion test | local; upstream submission unverified |
| 013-sdl-android-standard-utf8-ime.patch | sdl@5d249570393f7a37e037abf22cd6012a4cc56a71 | sdl/src/core/android/SDL_android.c, sdl/src/core/android/SDL_heaps_utf16.h | JNI UTF16 to standard UTF8 ingress | Native UTF16/UTF8 ingress tests | local; upstream submission unverified |
| 014-heaps-android-audio-channel-hooks.patch | heaps@3a970d27505131d00b2efd912511a1de094b374a | heaps/hxd/snd/Manager.hx, heaps/hxd/snd/Channel.hx | Conditional SDK raw channel/lifecycle protection | RawAudioRegression/AudioHealthRegression + native gate | local; upstream submission unverified |

## Validate before upgrading

`python3 scripts/test-patches.py` uses verified archives in isolated temporary directories. It tests fresh extraction, a second idempotent application, upgrading the published v0.2.0 patch set (`36a15d9`) to the current set, and explicit rejection of an incompatible target. The running application's `vendor/` is not changed by these tests.

For an upstream update, create a branch; update one dependency lock at a time; inspect every patch against that exact revision; preserve or remove each patch only after its owning regression passes; then run pure/native/Java, all-ABI build, APK and Android checks. Record removal/upstream commit in this matrix. Do not silently fall back to another native version.

If setup reports “neither applicable nor already applied”, retain the logs and source before re-extracting that one dependency from the locked archive. Do not delete application data or signing keys. `vendor/` is generated source; edits there are disposable unless captured as reviewed patches. Preserve exact line endings/context for idempotent upgrades.

The automated matrix covers the pinned stack and published-old extraction. It does not claim arbitrary future Heaps/HashLink/SDL upgrades are safe.
