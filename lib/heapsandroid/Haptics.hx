package heapsandroid;
import heapsandroid.internal.Native;
import heapsandroid.internal.PlatformPolicy;
class Haptics {
 public static var available(get,never):Bool;
 public static var enabled(default,set) = true;
 static function get_available():Bool return Native.hapticsAvailable();
 static function set_enabled(value:Bool):Bool {enabled = value; if(!value) cancel(); return value;}
 public static function vibrate(milliseconds:Int):Bool {
  return enabled && available && Native.hapticsVibrate(PlatformPolicy.hapticDuration(milliseconds));
 }
 public static function cancel():Void Native.hapticsCancel();
}
