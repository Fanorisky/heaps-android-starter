# Heaps Android SDK hardening implementation plan

**Version:** 1, Planner draft awaiting Advisor review.
**Spec:** ../specs/2026-11-14-sdk-hardening.md
**Goal:** Fix all audited reliability gaps and publish v0.2.1 with stronger measured regressions.

## Constraints
Keep applicationId io.heaps.android.proof, cert955cd26e9de2c1da3cde91b282886d12dc70c39b41172d2c74045568ea5a38d2, pinned Haxe4.3.6/HL1.15/SDL2/OpenAL1.24.3, Android24/GLES3 and all3 ABIs. VersionCode3/version0.2.1. No dependency upgrade/exception disabling/automatic recovery playback/unmeasured hardware claims. Native callbacks never allocate/callHaxe. Lock order session->audio lifetime, neverreverse.

## Shared contracts
Audio.error:AudioError (None0,NoDevice1,Unsupported2,Disconnected3,BackendFailure4,ResumeFailure5), routeGeneration:Int, recover():Bool, subscribeRouteChanges(Int->Void):Void->Void.
Native header int audio_get_state(),audio_get_error(),audio_check_health(); void audio_route_changed(). Health probe underlifetime mutex; failure pauses,clearsintent andreportsUnavailable; noautoresume. recover singleattemptabandonfocus/disposealloldchannels/context/device/createfreshmanager/register returnsPaused, doesnotgrantfocus/intent. Alloldchannelsreleased; app explicitlyrestartsounds.
ConditionalHeaps patch014 definesManager.heapsAndroidAfterCreate:Manager->Void,heapsAndroidBeforeUpdate:Void->Void,heapsAndroidBeforeDispose:Manager->Void,heapsAndroidFilterPause:Channel->Bool->Bool; outsideheapsandroid_audio_hooks unchanged. Hooksattachnew/oldManager andguardallchannels beforewalltime. Userrequestedpause separatefromeffectivegatepause. Androidshutdown/init preserveschannels/positions; Audio.shutdownterminal. PlatformownsAndroid.hx+Native; audioownsAudioNative+AudioRegression; rootownsheader/newReliabilityRegression/Features/runners.

## Tasks
- [ ] Root establishes ABI/header and failingregressioncontracts; baselinepure/native green.
- [ ] Platform fixesreversibleSDKsessions stop/start vsActivitydestroy, actualFG/windowfocustracking, synchronousstartsnapshot, uniqueepochsrejectstalepostedwork/focus/sensor/displaycallbacks. Brokenlibs retainSDLerrorpathwithoutnativecalls. Own JavaHeapsActivity/PlatformServices/helpers,nativeplatform/state,Android/Lifecycle/internalNative/platformtests. Testoldshutdowninitfailure,staleepoch,repeatstop,trueFGsnapshot,brokenloadproductionguardfixture+rootcorruptAPKdevicecase.
- [ ] PlatformaddsAudioDeviceCallback outputIDs snapshot active-sessiononly. Genuinechangesgenerationincrement/nativeaudio_route_changed clearsintent; nodupinitialcallback, noHaxefromJava. PollroutesonHaxethread. Testrouteadds/removes/duplicates/staleepochs/stoprace.
- [ ] Audio addsOperations.checkHealth(void*):int, checks ALC errors/disconnect continuouslyundermutex, latchesfailureUnavailableuntilrecover, concurrenthealth/unregister safe. Native/haxeerrorAPI+explicitfreshpausedrecoveryalloldchannelsinvalid. Ownnativeaudio/Audio/AudioNative/patch014/AudioRegression+tests. Regressioninjectedlatefailure/resumefailure/healthrace,realrecoverinvalidateandpaused.
- [ ] Audioguardsallraw/wrapperaudible/mutedvirtualManagerchannels viahooks, preservinguserpause changeswhilegated. Androidinitinstallhooks/attachexistingManager; futureSound.play Manageraftercreateattach. RawexplicitSound.play mayrequestintentfocus; autoFG/focusgainneverresumes. Testpausewalltime>duration,userpausewhilegated,rawplaywithoutAudio.init,SDKstoprestartpreservingpositions,newManager. Root/APIcontractreviewbeforeintegration.
- [ ] Root strengthensAndroidrunner with10realHOME/launch cycles andSDKshutdowninit; proof-onlyregressioncontrols captureactualstate/channelpositions/releaseflags/routegeneration/IME/display/sensors/prefs. Simulatedfocus/routeinjection belongsseparatetestbuild/fixture, productiondefaultAPKnoinjectors. Screenshotsdiagnosticsonly. ActualAudio.recoveroneattempt,statepaused,nosourcesuntilapprestart. Add minimalnative-loadfailurefixtureanddevicecase.
- [ ] Rootparameterizespatch/vendor destination and testsfreshpinnedextract/idempotencyv0.2oldcheckout/incompatiblefail. Patchmatrixall14 exactrepo/revision/path/reason/test/upstreamstatusunknownlocalwhereappropriate. No claimingupstreamsubmission.
- [ ] Rootfinaldocs/version/cert/CIbuild,downloadartifactupdatedeviceassertions/reviewreleasev0.2.1. Physicalmatrixspeaker/wired/BT/headsetlatency/routebatteryARM32ARM64/haptics markedpendingwhereunmeasured.

## Verification
./scripts/test-pure.sh,./scripts/test-native-host.sh, newJavafixture,python3scripts/test-patches.py,./scripts/generate-assets.sh--check,./scripts/generate-hlc.sh,./scripts/build-apk.sh--variant=proof,./scripts/test-android.shAPK SERIAL. Full3ABIverifierstablecert/exactversion, updatefromv0.2keepingprefs. CItestbuildstressandsimulatedfaults separate frompublishedproof; nofakephysicalhardwareclaims.

## Review focus
JNIepoch/signature/lockorder,rawchannelwalltime/userpause,latehealth/staleManager/recovery,asynccallbackdestroyloadfailure,patchupgradeandassertionquality.
