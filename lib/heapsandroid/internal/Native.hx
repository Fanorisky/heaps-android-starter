package heapsandroid.internal;
/** Genuine Android/HashLink primitives. Calls originate on the SDL game thread. */
extern class Native {
 @:hlNative("heapsandroid", "route_generation") public static function routeGeneration():Int;
 @:hlNative("heapsandroid", "prepare") public static function prepare():Void;
 @:hlNative("heapsandroid", "init") public static function init():Void;
 @:hlNative("heapsandroid", "shutdown") public static function shutdown():Void;
 @:hlNative("heapsandroid", "poll_lifecycle") public static function pollLifecycle():Int;
 @:hlNative("heapsandroid", "lifecycle_state") public static function lifecycleState():Int;
 @:hlNative("heapsandroid", "keyboard_show") public static function keyboardShow(x:Int,y:Int,width:Int,height:Int):Bool;
 @:hlNative("heapsandroid", "keyboard_hide") public static function keyboardHide():Void;
 @:hlNative("heapsandroid", "keyboard_active") public static function keyboardActive():Bool;
 @:hlNative("heapsandroid", "haptics_available") public static function hapticsAvailable():Bool;
 @:hlNative("heapsandroid", "haptics_vibrate") public static function hapticsVibrate(milliseconds:Int):Bool;
 @:hlNative("heapsandroid", "haptics_cancel") public static function hapticsCancel():Void;
 @:hlNative("heapsandroid", "sensor_available") public static function sensorAvailable(kind:Int):Bool;
 @:hlNative("heapsandroid", "sensor_enable") public static function sensorEnable(kind:Int):Bool;
 @:hlNative("heapsandroid", "sensor_disable") public static function sensorDisable(kind:Int):Void;
 @:hlNative("heapsandroid", "sensor_sample") public static function sensorSample(kind:Int):hl.Bytes;
 @:hlNative("heapsandroid", "display_immersive") public static function displayImmersive():Bool;
 @:hlNative("heapsandroid", "display_keep_awake") public static function displayKeepAwake():Bool;
 @:hlNative("heapsandroid", "display_set_immersive") public static function displaySetImmersive(value:Bool):Void;
 @:hlNative("heapsandroid", "display_set_keep_awake") public static function displaySetKeepAwake(value:Bool):Void;
 @:hlNative("heapsandroid", "display_insets") public static function displayInsets():hl.Bytes;
 @:hlNative("heapsandroid", "device_sdk") public static function deviceSdk():Int;
 @:hlNative("heapsandroid", "device_model") public static function deviceModel():hl.Bytes;
 @:hlNative("heapsandroid", "device_abis") public static function deviceAbis():hl.Bytes;
 @:hlNative("heapsandroid", "device_app_abi") public static function deviceAppAbi():hl.Bytes;
 @:hlNative("heapsandroid", "request_audio_focus") public static function requestAudioFocus():Bool;
 @:hlNative("heapsandroid", "abandon_audio_focus") public static function abandonAudioFocus():Void;
 @:hlNative("heapsandroid", "files_path") static function filesPathBytes():hl.Bytes;
 @:hlNative("heapsandroid", "cache_path") static function cachePathBytes():hl.Bytes;
 public static inline function filesPath():String return @:privateAccess String.fromUTF8(filesPathBytes());
 public static inline function cachePath():String return @:privateAccess String.fromUTF8(cachePathBytes());
}
