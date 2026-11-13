# Heaps Android host implementation plan

> Use subagent-driven-development for the independent platform, audio and demo/storage slices. Root owns integration, verification, signing and publication.

**Canonical version:** 1 — Planner draft, awaiting Advisor review.
**Goal:** Implement the user-approved Raymob-style reusable heapsandroid library and Android host, release v0.2.
**Spec:** ../specs/2026-11-13-heaps-android-host.md
**Architecture:** Standard Heaps resources/sound channels with hlopenal/OpenAL Soft, generic io.heaps.android SDL host, isolated Haxe API modules, native callback state dispatched on the Heaps thread.
**Tech stack:** Haxe4.3.6, existing pinned Heaps/HashLink1.15/SDL2.32.10, OpenAL Soft1.24.3 dc7d7054a5b4f3bec1dc23a42fd616a0847af948, NDK28.2.13676358, CMake3.30.3, AGP8.6.1, Gradle8.11.1.

## Global constraints
Android24+, GLES3, ARM32/ARM64/x86_64. Preserve existing game rules and62 assertions. No new campaign/store signing/ads/network/mic/camera. No Haxe callbacks or GC allocation from Java/UI/audio/sensor threads. No broad exception disabling for the known ARM32 NativeBridge defect. Root publishes after review and verification. OpenAL Soft stays separately packaged and its LGPL source/notice requirements are included.

## Frozen public contracts
Host io.heaps.android.HeapsActivity extends SDLActivity. Haxelib classPath lib. Default app.name=HeapsAndroidProof, app.application_id=io.heaps.android.proof, app.version_code=2, app.version_name=0.2.0, app.orientation=landscape, app.immersive=true, app.keep_awake=true. Drive manifest/labels/config from properties; do not rewrite Java. Remove unconditional create-time fullscreen; apply display config after window exists and test immersive=false.

Under lib/heapsandroid:
- Android.init():Void (idempotent, after window creation), update():Void (main-thread frame poll/dispatch), shutdown():Void (sensor/keyboard/focus/haptics/platform cleanup).
- LifecycleEvent:Int enum Foreground,Background,FocusGained,FocusLost; Lifecycle.foreground/focused read-only Bool; subscribe(LifecycleEvent->Void):Void->Void unsubscribe function. Fixed/coalescing event queue.
- KeyboardRect={x:Int,y:Int,width:Int,height:Int}; Keyboard.active read-only Bool; show(?KeyboardRect):Bool, hide():Void. Text goes through normal hxd.Window text events; background cancels composition and hides IME.
- Haptics.available read-only Bool; enabled:Bool; vibrate(milliseconds:Int):Bool (clamp1..2000), cancel():Void. Missing hardware/disabled/unusable state returns false; normal VIBRATE permission.
- SensorKind:Int enum Accelerometer,Gyroscope; SensorSample={x:Float,y:Float,z:Float,timestampNs:haxe.Int64}; Sensors.available(kind):Bool, enable(kind):Bool, disable(kind):Void, sample(kind):Null<SensorSample>. Request20,000us, latest complete sample, unregister both on background/shutdown.
- SafeInsets={left:Int,top:Int,right:Int,bottom:Int}; Display.immersive/keepAwake/safeInsets read-only properties; setImmersive(Bool):Void,setKeepAwake(Bool):Void.
- DeviceInfo={sdk:Int,model:String,supportedAbis:Array<String>,appAbi:String}; Device.info():DeviceInfo. No serial/ad IDs.
- Storage.validateRelativePath(String):Bool; readFile(String):Null<Bytes>,writeFileAtomic(String,Bytes):Bool,deleteFile(String):Bool,readCache(String):Null<Bytes>,writeCacheAtomic(String,Bytes):Bool. Reject empty/absolute/NUL/dot/dotdot/backslash escape/canonical escape. Same-directory temporary, flush/close/rename.
- Preferences.open(name:String,schemaVersion:Int,migrate:(Int,Dynamic)->Dynamic):Preferences; getBool/getInt/getFloat/getString(key,fallback), matching set methods, remove(key),commit():Bool. Versioned typed JSON atomic writes; corrupt fallback/migration; fixture-backed legacy best-score preservation without changing its serialized key/format.
- AudioState:Int Unavailable0,Paused1,Running2. Audio.state read-only; sfxVolume/musicVolume Float (clamp0..1),sfxMuted/musicMuted Bool. init():Bool,playSfx(sound:hxd.res.Sound,?volume:Float=1):hxd.snd.Channel,playMusic(sound,?loop:Bool=true):hxd.snd.Channel,stopMusic():Void,pause():Void,resume():Bool,shutdown():Void. One music channel, live SFX volume/mute updates, position-preserving device pause.

Root-owned app/src/main/cpp/include/audio_gate.h declares extern-C audio_register(void*),audio_unregister(),audio_set_foreground(int),audio_set_focus(int),audio_set_intent(int),audio_get_state():int (Unregistered0/Paused1/Running2). Registered+foreground+focus+intent required to run. Background/focus loss pauses real device immediately and clears intent; recovery alone cannot resume. Unregister pauses under same lock before pointer clear. Use actual ALC_SOFT_pause_device functions; no Haxe work in callbacks. Audio.pause also abandons focus. Native state observed through Android.update.

SDL_TEXTINPUT patch walks full text buffer and emits one packed UTF8 scalar event per1..4bytes, preserves current Window decoder contract, replacementU+FFFD for malformed/incomplete, no rawUTF32 or first4bytes-only truncation. Backspace stays key event. Editor removes one Unicode scalar.

## Ownership and tasks
- [ ] Task1 Root integration: properties/Gradle/manifest/rootCMake/wrapper, haxelib.json+mappings, locks/downloads, shared audio_gate.h, signing/CI/install/verification scripts, notices/docs. Establish header/contracts before workers; lock OpenAL archive; integrate worker CMake fragments; HL OpenAL extension pointer imports hidden to prevent interposition; libopenal.so separate. Generate HLC via existing no-compilation pipeline. Derive APK/appId/activity/ABIs from actual metadata. Add dedicated testRelease signing; main/tag must fail missing stable inputs, fork PR may ephemeral debug with no upgrade claim.
- [ ] Task2 Platform executor exclusive app/src/main/java/io/heaps/android/**, app/src/main/cpp/platform/** and fragment, SDL text patches, lib/heapsandroid/{Android,Lifecycle,Keyboard,Haptics,Sensors,Display,Device}.hx, internal/Native.hx, platform tests. Failing tests before code: queue ordering/coalescing/main-thread dispatch; UTF8 pasted ASCII/mixed accent/CJK/emoji/invalid/truncated; display true/false; haptics bounds/unavailable; sensors enable/disable/latest/timestamp/background. Generic Java host and JNI/native state; no Haxe work from callbacks. Consume gate header/focus entry points, no root-file writes.
- [ ] Task3 Audio executor exclusive app/src/main/cpp/audio/** and fragment, lib/heapsandroid/Audio.hx and internal/AudioNative.hx, HL OpenAL patches, audio tests. Failing gate combination/lifetime/race tests, loss-clears-intent, recovery-no-autoresume; volume/mutes/live channels/music ownership/position tests. Build pinned OpenAL OpenSL; hidden binding imports; actual Heaps device register/unregister before destruction. Consume platform focus request/abandon entry points and root header; no root-file writes.
- [ ] Task4 Demo/storage executor exclusive src/**, resource sources/assets/generator, lib/heapsandroid/{Storage,Preferences}.hx and tests. Preserve62 assertions; failing paths/atomic/typed/corrupt/migration/legacy fixture tests; Unicode editor/nonBMP/backspace/cancel tests; game event reporting tests. Original deterministic PNG/WAV generation with byte-for-byte --check. Features screen tests audio buttons/loop/volumes/mute, keyboard/editor,haptics,sensors,display,insets,deviceABI. Main minimal refactor for reusable library plus unchanged game.

Root integrates platform then audio then demo; review each slice, run focused tests at boundaries. Startup wires Android.init/update/shutdown. Native callback order immediate silence/IME cancel/sensor unregister then queue; cleanup channels/music->gate unregister->Heaps audio disposal->platform shutdown. Review before release.

## Review focus
1 Callback thread/queue/ALC lifetime races and idempotent shutdown.
2 UTF8 complete commits/nonBMP/delete/cancel.
3 Audio symbol interposition/state/position/focus leaks and evidence claims.
4 Storage traversal/atomic/corrupt/typed/migration and legacy data compatibility.
5 Metadata/namespace/ABIs/immersivefalse/signing identity/secrets/fork artifact claims.

## Verification
./scripts/test-host.sh: original62 assertions + platform/audio-gate/storage/preferences/Unicode/game events/lifecycle allzero failures.
./scripts/generate-assets.sh --check: PNG/WAV reproduce and licenses.
./gradlew --no-daemon clean :app:assembleDebug: threeABI APK.
./scripts/verify-apk.sh APK and ./scripts/verify-native-symbols.sh APK: metadata appId/host/version/minSDK, newnormalVIBRATE permission, SDL2/hl/main/openal eachABI, correct JNI/HL exports/noOpenALpointerglobals.
./scripts/test-emulator.sh APK: metadata install/launch, Features controls/lifecycle/IME/sensors/audio track progress or PCM where possible; do not call stream activity physical speaker listening. ARM32 NativeBridge setjmp defect documented; ARM32 compile/nativechecks and existing physical Android10 evidence ornewphysicaltest.
./gradlew :app:assembleTestRelease: stable test cert verify, main/tag fail missing credentials, forkdebug markedephemeral. Public certificate digest matches.

## Signing/publication
Generate dedicated development key under ignored signing files with separate recoverable backup. Main/tag secrets: HEAPS_ANDROID_TEST_KEYSTORE (base64), TEST_STORE_PASSWORD,TEST_KEY_PASSWORD,TEST_KEY_ALIAS; supply through stdin/privatefiles, never print. Production signing excluded. Root publishes v0.2 testAPK/checksums/publiccert+LGPLsource info after fullgate, user devicechecks audibility/haptics/ARM32.
