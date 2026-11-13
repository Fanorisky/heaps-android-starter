# Heaps Android host implementation plan

> Use subagent-driven-development for the independent platform, audio and demo/storage slices. Root owns integration, verification, signing and publication.

**Canonical version:** 2 — Advisor approved. A01–A07 incorporated and confirmed.
**Goal:** Implement the user-approved Raymob-style reusable heapsandroid library and Android host, release v0.2.
**Spec:** ../specs/2026-11-13-heaps-android-host.md
**Architecture:** Standard Heaps resources/sound channels with hlopenal/OpenAL Soft, generic io.heaps.android SDL host, isolated Haxe API modules, native callback state dispatched on the Heaps thread.
**Tech stack:** Haxe4.3.6, existing pinned Heaps/HashLink1.15/SDL2.32.10, OpenAL Soft1.24.3 dc7d7054a5b4f3bec1dc23a42fd616a0847af948, NDK28.2.13676358, CMake3.30.3, AGP8.6.1, Gradle8.11.1.

## Global constraints
Android24+, GLES3, ARM32/ARM64/x86_64. Preserve existing game rules and62 assertions. No new campaign/store signing/ads/network/mic/camera. No Haxe callbacks or GC allocation from Java/UI/audio/sensor threads. No broad exception disabling for the known ARM32 NativeBridge defect. Root publishes after review and verification. OpenAL Soft stays separately packaged and its LGPL source/notice requirements are included.

## Frozen public contracts
Host io.heaps.android.HeapsActivity extends SDLActivity. Haxelib classPath lib. Default app.name=Heaps Android Proof, app.application_id=io.heaps.android.proof, app.version_code=2, app.version_name=0.2.0, app.orientation=portrait, app.immersive=true, app.keep_awake=true. Drive manifest/labels/config from properties; do not rewrite Java. Keep existing SDL fullscreen patch7; apply display config after window exists and actively clear fullscreen/systemUI flags for immersive=false. One validated orientation source drives manifest and pre-window SDL hint: portrait -> sensorPortrait / Portrait PortraitUpsideDown; landscape -> sensorLandscape / LandscapeLeft LandscapeRight; unspecified -> unspecified / no restriction. Validate appID syntax, nonempty appname/version, positive versionCode and booleans.

Under lib/heapsandroid:
- Android.prepare():Void (idempotent BEFORE new Main, pre-window SDL orientation hint), init():Void (idempotent after window creation, apply display defaults/services and install nonblocking haxe.MainLoop event priority100), update():Void (poll native lifecycle/window state -> Audio.poll -> lifecycle subscriber dispatch -> keyboard/timers), shutdown():Void (stop pump and sensor/keyboard/focus/haptics/platform cleanup). Manual update calls guard re-entry/duplicate dispatch. Priority100 pump runs before Heaps priority0 sound-manager updates.
- LifecycleEvent:Int enum Foreground,Background,FocusGained,FocusLost; Lifecycle.foreground/focused read-only Bool; subscribe(LifecycleEvent->Void):Void->Void unsubscribe function. Fixed/coalescing event queue; focused means WINDOW focus only, independent from AudioManager focus.
- KeyboardRect={x:Int,y:Int,width:Int,height:Int}; Keyboard.active read-only Bool; show(?KeyboardRect):Bool, hide():Void. Text goes through normal hxd.Window text events; background cancels composition and hides IME.
- Haptics.available read-only Bool; enabled:Bool; vibrate(milliseconds:Int):Bool (clamp1..2000), cancel():Void. Missing hardware/disabled/unusable state returns false; normal VIBRATE permission.
- SensorKind:Int enum Accelerometer,Gyroscope; SensorSample={x:Float,y:Float,z:Float,timestampNs:haxe.Int64}; Sensors.available(kind):Bool, enable(kind):Bool, disable(kind):Void, sample(kind):Null<SensorSample>. Request20,000us; exact32-byte sample packet three IEEE754 doubles plus signed64-bit nanoseconds, no float timestamp conversion. Versioned doublebuffer/seqlock; requested flags survive background, listeners unregister there and re-register requested/available sensors on foreground. Latest complete sample; unavailable/inactive returns null.
- SafeInsets={left:Int,top:Int,right:Int,bottom:Int}; Display.immersive/keepAwake/safeInsets read-only properties; setImmersive(Bool):Void,setKeepAwake(Bool):Void.
- DeviceInfo={sdk:Int,model:String,supportedAbis:Array<String>,appAbi:String}; Device.info():DeviceInfo. No serial/ad IDs.
- Storage.validateRelativePath(String):Bool; readFile(String):Null<Bytes>,writeFileAtomic(String,Bytes):Bool,deleteFile(String):Bool,readCache(String):Null<Bytes>,writeCacheAtomic(String,Bytes):Bool. Reject empty/absolute/NUL/dot/dotdot/backslash escape/canonical escape. Same-directory temporary, flush/close/rename.
- Preferences.open(name:String,schemaVersion:Int,migrate:(Int,Dynamic)->Dynamic):Preferences; getBool/getInt/getFloat/getString(key,fallback), matching set methods, remove(key),commit():Bool. Versioned typed JSON atomic writes; corrupt fallback/migration; fixture-backed legacy best-score FILEFORMAT/key preservation, without claiming access/migration across the new applicationID private sandbox.
- AudioState:Int Unavailable0,Paused1,Running2. Audio.state read-only; sfxVolume/musicVolume Float (clamp0..1),sfxMuted/musicMuted Bool. init():Bool,poll():Void,playSfx(sound:hxd.res.Sound,?volume:Float=1):Null<hxd.snd.Channel>,playMusic(sound,?loop:Bool=true):Null<hxd.snd.Channel>,stopMusic():Void,pause():Void,resume():Bool,shutdown():Void. One music channel, live SFX volume/mute updates, position-preserving device pause.

Root-owned app/src/main/cpp/include/audio_gate.h declares extern-C int audio_register(void*),void audio_unregister(),void audio_set_foreground(int),void audio_begin_focus_request(intgeneration),void audio_set_focus(intgeneration,intfocused),void audio_abandon_focus(intgeneration),void audio_set_intent(int),int audio_get_state() (Unregistered0/Paused1/Running2). Registration NULL0, samepointer idempotent1, differentactivepointer0. Firstsuccess retainsforeground, resetsfocus/intent/generation. Positive requestgeneration supersedesprior; stale set/abandon callbacks ignored. FG/audiofocus loss immediately pauses device and clearsintent; recovery neverrestoresintent. All real ALC pause/resume/unregister share lifetime lock; unregisterpauses,invalidatesgeneration,clears pointer beforedevice destruction; repeatedunregister no-op.

Platform-owned internal/Native.hx exact requestAudioFocus():Bool and abandonAudioFocus():Void. Request fromHaxeSDLthread synchronously callsJavaAudioManager; listener runsmainHandler, capturesmonotonicpositivegeneration, checksalive/active plusnativegeneration. Delayedgain notaccepted; trueonlyimmediategrant, failed/delayedrequest abandoned/inactivated. Registerdevice BEFORE requestfocus. Audio.init onlytrueforactual hxd.snd.openal.Driver+nonnullcontext/device+register1; partialfailure abandons/unregisters/cleans resources; virtualchannels neverproof. Playback unavailable/denied returnsnull.

Audio.poll sets every owned live music/SFX Channel.pause=true forPaused/Unavailable beforeManager.updateVirtualChannels. Explicit resume requestsfocus thenintent and sets Channel.pause=false throughrealsetter(resetlastStamp)withoutresettingposition. Muted/virtual channels freeze too. Thepriority100 Android pump precedesManagerpriority0; Audio.pause also abandonsfocus. Explicit play calls mayinvoke resume, foreground/focusgain alone cannot. Trackone music andallliveSFX forvolumes/mutes.

SDL_TEXTINPUT patch walks full text buffer and emits one packed UTF8 scalar event per1..4bytes, preserves current Window decoder contract, replacementU+FFFD for malformed/incomplete, no rawUTF32 or first4bytes-only truncation. Backspace stays key event. Editor removes one Unicode scalar.

## Ownership and tasks
- [ ] Task1 Root integration: properties/Gradle/manifest/rootCMake/wrapper, haxelib.json+mappings, locks/downloads, shared audio_gate.h, signing/CI/install/verification scripts, notices/docs. Establish header/contracts before workers; lock OpenAL archive; integrate worker CMake fragments; HL OpenAL extension pointer imports hidden to prevent interposition; libopenal.so separate. Generate HLC via existing no-compilation pipeline. Derive APK/appId/activity/ABIs from actual metadata. Add dedicated testRelease signing; main and push v* tags require all four stable inputs/certdigest, PR neverreadssecrets and assemblesDebug ephemerally withno upgradeclaim.
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
./scripts/test-pure.sh: interpreter-safe game/controller/storage/editor suites, original62 plusnew allzero. ./scripts/test-native-host.sh: compiledhostC++ UTF8/gate/generation/lifetimerace tests withoutJNI, sanitizer-clean supportedruns. ./scripts/test-hl-audio.sh APK SERIAL: Android-backed real Heaps Manager/Channel regression, not a host VM. Audio executor owns tests/android/AudioRegression.hx, a nonblocking state machine using real sample resources/channels that checks audible and muted/virtual loop position before/after pause and explicit resume. Demo Features screen invokes it from an Audio Checks button and prints structured AUDIO_TEST_PASS/FAIL. Root runner installs/launches metadata-derived APK, presses that control and waits for results. Test-only code stays under tests/android; proof build includes its class path. No fake channels or extra host HashLink runtime required.
./scripts/generate-assets.sh --check: PNG/WAV reproduce and licenses.
./gradlew --no-daemon clean :app:assembleDebug: threeABI APK.
./scripts/verify-apk.sh APK and ./scripts/verify-native-symbols.sh APK: metadata appId/host/version/minSDK, newnormalVIBRATE permission, SDL2/hl/main/openal eachABI, correct JNI/HL exports/noOpenALpointerglobals.
./scripts/test-android.sh APK "$ANDROID_SERIAL": metadata install/launch, Features controls/lifecycle/IME/sensors/audio track progress or PCM where possible; do not call stream activity physical speaker listening. ARM32 NativeBridge setjmp defect documented; ARM32 compile/nativechecks and existing Galaxy A10/Android11 evidence is baselineonly; newphysicalaudibility/haptic checks remainpending. Do notdisableexceptionsforsimulatedARM32 NativeBridge setjmp failure.
./gradlew :app:assembleTestRelease: stable test cert verify, main/tag fail missing credentials, forkdebug markedephemeral. Public certificate digest matches.

## Signing/publication
Generate dedicated development key under ignored signing files with separate recoverable backup. Main/tag secrets: HEAPS_ANDROID_TEST_KEYSTORE (base64),HEAPS_ANDROID_TEST_STORE_PASSWORD,HEAPS_ANDROID_TEST_KEY_PASSWORD,HEAPS_ANDROID_TEST_KEY_ALIAS; supply through stdin/privatefiles, never print. Production signing excluded. Root publishes v0.2 testAPK/checksums/publiccert+LGPLsource info after fullgate, user devicechecks audibility/haptics/ARM32.

## Findings ledger
A01 INCORPORATED — exact approved secret names; explicit PR/main/tag variants, stableidentityfailures.
A02 INCORPORATED — portrait/defaultlabel and prepare-before-window; singlevalidatedorientation source.
A03 INCORPORATED — exact platformfocus methods, separatewindow/audiofocus andAndroid/Audio poll order.
A04 INCORPORATED — generationtokens, NULL/same/differentregistration, lockedunregister andpartialcleanup.
A05 INCORPORATED — nullableplayback andactualdevice/context/registrationavailability.
A06 INCORPORATED — priority100 pump beforemanager0, realChannel.pause freezesvirtualtime andsetterresetslastStamp.
A07 INCORPORATED — pure/native/real-channel/Android evidence separation andcorrectA10Android11 baseline; real-channel runner is Android-backed and specified above.
