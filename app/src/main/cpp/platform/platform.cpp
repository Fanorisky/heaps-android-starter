#define HL_NAME(n) heapsandroid_##n
#include <hl.h>
#include <SDL.h>
#include <SDL_system.h>
#include <jni.h>
#include <android/log.h>
#include <atomic>
#include <cstring>
#include <string>
#include "audio_gate.h"
#include "platform_state.h"
#include "session_epoch.h"

extern "C" void sdl_cancel_text_input(void);
namespace {
heapsandroid::PlatformState state;
heapsandroid::SessionEpoch sessions;
std::atomic<int> routeGeneration(0);
std::mutex insetLock;
int insets[4] = {};
std::atomic<bool> initialized(false);

struct JavaCall {
 JNIEnv *env;
 jobject activity;
 jclass cls;
 JavaCall():env(static_cast<JNIEnv*>(SDL_AndroidGetJNIEnv())),activity(nullptr),cls(nullptr) {
  if(env){activity=static_cast<jobject>(SDL_AndroidGetActivity());if(activity)cls=env->GetObjectClass(activity);}
 }
 ~JavaCall(){if(env){if(cls)env->DeleteLocalRef(cls);if(activity)env->DeleteLocalRef(activity);}}
 bool failed(){if(env && env->ExceptionCheck()){env->ExceptionClear();return true;}return false;}
 jmethodID method(const char *name,const char *signature){if(!env||!cls)return nullptr;jmethodID id=env->GetMethodID(cls,name,signature);if(failed())return nullptr;return id;}
 bool boolean(const char *name){jmethodID id=method(name,"()Z");if(!id)return false;bool v=env->CallBooleanMethod(activity,id);return !failed()&&v;}
 bool booleanInt(const char *name,int value){jmethodID id=method(name,"(I)Z");if(!id)return false;bool v=env->CallBooleanMethod(activity,id,value);return !failed()&&v;}
 int integer(const char *name){jmethodID id=method(name,"()I");if(!id)return 0;int v=env->CallIntMethod(activity,id);return failed()?0:v;}
 void call(const char *name){jmethodID id=method(name,"()V");if(id){env->CallVoidMethod(activity,id);failed();}}
 void callInt(const char *name,int value){jmethodID id=method(name,"(I)V");if(id){env->CallVoidMethod(activity,id,value);failed();}}
 void callBool(const char *name,bool value){jmethodID id=method(name,"(Z)V");if(id){env->CallVoidMethod(activity,id,(jboolean)value);failed();}}
 // Standard UTF8, rather than JNI's modified UTF8, preserves non-BMP model/path text.
 std::string string(const char *name){
  jmethodID id=method(name,"()Ljava/lang/String;");if(!id)return {};
  jstring value=static_cast<jstring>(env->CallObjectMethod(activity,id));if(failed()||!value)return {};
  jsize length=env->GetStringLength(value);const jchar *chars=env->GetStringChars(value,nullptr);std::string out;
  if(chars)for(jsize i=0;i<length;i++){
   uint32_t cp=chars[i];if(cp>=0xd800&&cp<=0xdbff&&i+1<length&&chars[i+1]>=0xdc00&&chars[i+1]<=0xdfff){cp=0x10000+((cp-0xd800)<<10)+(chars[++i]-0xdc00);}else if(cp>=0xd800&&cp<=0xdfff)cp=0xfffd;
   if(cp<0x80)out.push_back((char)cp);
   else if(cp<0x800){out.push_back((char)(0xc0|(cp>>6)));out.push_back((char)(0x80|(cp&63)));}
   else if(cp<0x10000){out.push_back((char)(0xe0|(cp>>12)));out.push_back((char)(0x80|((cp>>6)&63)));out.push_back((char)(0x80|(cp&63)));}
   else{out.push_back((char)(0xf0|(cp>>18)));out.push_back((char)(0x80|((cp>>12)&63)));out.push_back((char)(0x80|((cp>>6)&63)));out.push_back((char)(0x80|(cp&63)));}
  }
  if(chars)env->ReleaseStringChars(value,chars);env->DeleteLocalRef(value);failed();return out;
 }
};
vbyte *bytes(const std::string &text){vbyte *out=hl_alloc_bytes((int)text.size()+1);memcpy(out,text.c_str(),text.size()+1);return out;}
SDL_Window *window(){SDL_Window *w=SDL_GetKeyboardFocus();if(!w)w=SDL_GetMouseFocus();if(!w)w=SDL_GetWindowFromID(1);return w;}
}

// Callback exports: session -> native state/audio lifetime; no GC allocation.
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeStart(JNIEnv*,jclass,jlong epoch,jboolean fg,jboolean focus){
 sessions.start(epoch,[&]{
  audio_set_sdk_active(0);state.reset();
  {std::lock_guard<std::mutex> g(insetLock);memset(insets,0,sizeof(insets));}
  audio_set_foreground(fg?1:0);state.setForeground(fg!=0);
  audio_set_window_focus(focus?1:0);state.setFocused(focus!=0);
  audio_set_sdk_active(1); // Publish eligibility LAST, synchronously before Android.init returns.
 });
}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeStop(JNIEnv*,jclass,jlong epoch){
 sessions.stop(epoch,[&]{
  audio_set_sdk_active(0); // Silence output and invalidate intent FIRST.
  audio_set_foreground(0);audio_set_window_focus(0);
  state.reset();initialized=false;sdl_cancel_text_input();
  {std::lock_guard<std::mutex> g(insetLock);memset(insets,0,sizeof(insets));}
 });
}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeForeground(JNIEnv*,jclass,jlong epoch,jboolean value){
 sessions.run(epoch,[&]{
  bool backgroundTransition=!value && (state.lifecycleState()&1)!=0;
  audio_set_foreground(value?1:0);state.setForeground(value!=0);
  if(!value){sdl_cancel_text_input();SDL_FlushEvent(SDL_KEYDOWN);SDL_FlushEvent(SDL_FINGERDOWN);SDL_FlushEvent(SDL_FINGERMOTION);}
  if(backgroundTransition){
   unsigned char sensorPacket[32];
   int sensorSamples=(state.readSensor(0,sensorPacket)?1:0)|(state.readSensor(1,sensorPacket)?2:0);
   // Observe the paused callback state while SDL's game thread may be suspended.
   // peekState never probes OpenAL health or allocates HashLink objects.
   __android_log_print(ANDROID_LOG_INFO,"HeapsAndroid",
    "HEAPS_BACKGROUND epoch=%lld audio=%d lifecycle=%d sensors=%d text=%d",
    static_cast<long long>(epoch),audio_peek_state(),state.lifecycleState(),sensorSamples,
    SDL_IsTextInputActive()==SDL_TRUE?1:0);
  }
 });
}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeWindowFocus(JNIEnv*,jclass,jlong epoch,jboolean value){sessions.run(epoch,[&]{audio_set_window_focus(value?1:0);state.setFocused(value!=0);});}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeBeginFocus(JNIEnv*,jclass,jlong epoch,jint generation){sessions.run(epoch,[&]{audio_begin_focus_request(generation);});}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeAudioFocus(JNIEnv*,jclass,jlong epoch,jint generation,jboolean value){sessions.run(epoch,[&]{audio_set_focus(generation,value?1:0);});}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeAbandonFocus(JNIEnv*,jclass,jlong epoch,jint generation){sessions.run(epoch,[&]{audio_abandon_focus(generation);});}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeSensorActive(JNIEnv*,jclass,jlong epoch,jint kind,jboolean active){sessions.run(epoch,[&]{state.sensorActive(kind,active!=0);});}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeSensor(JNIEnv*,jclass,jlong epoch,jint kind,jdouble x,jdouble y,jdouble z,jlong timestamp){sessions.run(epoch,[&]{state.publishSensor(kind,x,y,z,timestamp);});}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeDisplay(JNIEnv*,jclass,jlong epoch,jboolean immersive,jboolean awake){sessions.run(epoch,[&]{state.setDisplay(immersive!=0,awake!=0);});}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeInsets(JNIEnv*,jclass,jlong epoch,jint left,jint top,jint right,jint bottom){sessions.run(epoch,[&]{std::lock_guard<std::mutex> g(insetLock);insets[0]=left;insets[1]=top;insets[2]=right;insets[3]=bottom;});}
extern "C" JNIEXPORT void JNICALL Java_io_heaps_android_PlatformServices_nativeRouteChanged(JNIEnv*,jclass,jlong epoch){sessions.run(epoch,[&]{
 int generation=routeGeneration.load();if(generation<INT32_MAX)routeGeneration.store(generation+1);
 audio_route_changed();
});}

HL_PRIM void HL_NAME(prepare)(){
 JavaCall java;std::string orientation=java.string("configuredOrientation");
 const char *hint=orientation=="portrait"?"Portrait PortraitUpsideDown":orientation=="landscape"?"LandscapeLeft LandscapeRight":"";
 SDL_SetHint(SDL_HINT_ORIENTATIONS,hint);
}
HL_PRIM void HL_NAME(init)(){
 if(initialized.exchange(true))return;
 JavaCall java;SDL_Window *w=window();if(w)SDL_SetWindowFullscreen(w,java.boolean("configuredImmersive")?SDL_WINDOW_FULLSCREEN_DESKTOP:0);
 java.call("initializeServices");
}
HL_PRIM void HL_NAME(shutdown)(){if(!initialized.exchange(false))return;JavaCall java;java.call("shutdownServices");}
HL_PRIM int HL_NAME(poll_lifecycle)(){return state.poll();}
HL_PRIM int HL_NAME(lifecycle_state)(){return state.lifecycleState();}
HL_PRIM int HL_NAME(route_generation)(){return routeGeneration.load();}
HL_PRIM bool HL_NAME(keyboard_show)(int x,int y,int width,int height){
 if(!(state.lifecycleState()&1))return false;
 SDL_Window *w=window();if(!w||!SDL_HasScreenKeyboardSupport())return false;
 SDL_Rect rect={x,y,width<1?1:width,height<1?1:height};SDL_SetTextInputRect(&rect);SDL_StartTextInput();return SDL_IsTextInputActive()==SDL_TRUE;
}
HL_PRIM void HL_NAME(keyboard_hide)(){sdl_cancel_text_input();JavaCall java;java.call("cancelKeyboard");}
HL_PRIM bool HL_NAME(keyboard_active)(){SDL_Window *w=window();return (state.lifecycleState()&1)&&w&&SDL_IsTextInputActive()==SDL_TRUE&&SDL_IsScreenKeyboardShown(w)==SDL_TRUE;}
HL_PRIM bool HL_NAME(haptics_available)(){JavaCall java;return java.boolean("hapticsAvailable");}
HL_PRIM bool HL_NAME(haptics_vibrate)(int milliseconds){JavaCall java;return java.booleanInt("vibrate",milliseconds<1?1:milliseconds>2000?2000:milliseconds);}
HL_PRIM void HL_NAME(haptics_cancel)(){JavaCall java;java.call("cancelVibration");}
HL_PRIM bool HL_NAME(sensor_available)(int kind){JavaCall java;return java.booleanInt("sensorAvailable",kind);}
HL_PRIM bool HL_NAME(sensor_enable)(int kind){
 JavaCall java;if(!state.sensorEnable(kind,java.booleanInt("sensorAvailable",kind)))return false;
 if(java.booleanInt("enableSensor",kind))return true;state.sensorDisable(kind);return false;
}
HL_PRIM void HL_NAME(sensor_disable)(int kind){state.sensorDisable(kind);JavaCall java;java.callInt("disableSensor",kind);}
HL_PRIM vbyte *HL_NAME(sensor_sample)(int kind){unsigned char packet[32];if(!state.readSensor(kind,packet))return nullptr;vbyte *out=hl_alloc_bytes(32);memcpy(out,packet,32);return out;}
HL_PRIM bool HL_NAME(display_immersive)(){return state.immersive();}
HL_PRIM bool HL_NAME(display_keep_awake)(){return state.keepAwake();}
HL_PRIM void HL_NAME(display_set_immersive)(bool value){SDL_Window *w=window();if(w)SDL_SetWindowFullscreen(w,value?SDL_WINDOW_FULLSCREEN_DESKTOP:0);JavaCall java;java.callBool("applyImmersive",value);}
HL_PRIM void HL_NAME(display_set_keep_awake)(bool value){JavaCall java;java.callBool("applyKeepAwake",value);}
HL_PRIM vbyte *HL_NAME(display_insets)(){vbyte *out=hl_alloc_bytes(16);std::lock_guard<std::mutex> g(insetLock);memcpy(out,insets,16);return out;}
HL_PRIM int HL_NAME(device_sdk)(){JavaCall java;return java.integer("deviceSdk");}
HL_PRIM vbyte *HL_NAME(device_model)(){JavaCall java;return bytes(java.string("deviceModel"));}
HL_PRIM vbyte *HL_NAME(device_abis)(){JavaCall java;return bytes(java.string("supportedAbis"));}
HL_PRIM vbyte *HL_NAME(files_path)(){JavaCall java;return bytes(java.string("filesPath"));}
HL_PRIM vbyte *HL_NAME(cache_path)(){JavaCall java;return bytes(java.string("cachePath"));}
HL_PRIM vbyte *HL_NAME(device_app_abi)(){
#if defined(__aarch64__)
 return bytes("arm64-v8a");
#elif defined(__arm__)
 return bytes("armeabi-v7a");
#elif defined(__x86_64__)
 return bytes("x86_64");
#else
#error Unsupported application ABI
#endif
}
HL_PRIM bool HL_NAME(request_audio_focus)(){JavaCall java;return java.boolean("requestAudioFocus");}
HL_PRIM void HL_NAME(abandon_audio_focus)(){JavaCall java;java.call("abandonAudioFocus");}

DEFINE_PRIM(_VOID,prepare,_NO_ARG);
DEFINE_PRIM(_VOID,init,_NO_ARG);
DEFINE_PRIM(_VOID,shutdown,_NO_ARG);
DEFINE_PRIM(_I32,poll_lifecycle,_NO_ARG);
DEFINE_PRIM(_I32,lifecycle_state,_NO_ARG);
DEFINE_PRIM(_I32,route_generation,_NO_ARG);
DEFINE_PRIM(_BOOL,keyboard_show,_I32 _I32 _I32 _I32);
DEFINE_PRIM(_VOID,keyboard_hide,_NO_ARG);
DEFINE_PRIM(_BOOL,keyboard_active,_NO_ARG);
DEFINE_PRIM(_BOOL,haptics_available,_NO_ARG);
DEFINE_PRIM(_BOOL,haptics_vibrate,_I32);
DEFINE_PRIM(_VOID,haptics_cancel,_NO_ARG);
DEFINE_PRIM(_BOOL,sensor_available,_I32);
DEFINE_PRIM(_BOOL,sensor_enable,_I32);
DEFINE_PRIM(_VOID,sensor_disable,_I32);
DEFINE_PRIM(_BYTES,sensor_sample,_I32);
DEFINE_PRIM(_BOOL,display_immersive,_NO_ARG);
DEFINE_PRIM(_BOOL,display_keep_awake,_NO_ARG);
DEFINE_PRIM(_VOID,display_set_immersive,_BOOL);
DEFINE_PRIM(_VOID,display_set_keep_awake,_BOOL);
DEFINE_PRIM(_BYTES,display_insets,_NO_ARG);
DEFINE_PRIM(_I32,device_sdk,_NO_ARG);
DEFINE_PRIM(_BYTES,device_model,_NO_ARG);
DEFINE_PRIM(_BYTES,device_abis,_NO_ARG);
DEFINE_PRIM(_BYTES,device_app_abi,_NO_ARG);
DEFINE_PRIM(_BYTES,files_path,_NO_ARG);
DEFINE_PRIM(_BYTES,cache_path,_NO_ARG);
DEFINE_PRIM(_BOOL,request_audio_focus,_NO_ARG);
DEFINE_PRIM(_VOID,abandon_audio_focus,_NO_ARG);
