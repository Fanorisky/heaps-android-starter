package heapsandroid;
import heapsandroid.internal.Native;
typedef SafeInsets = {left:Int,top:Int,right:Int,bottom:Int};
class Display {
 public static var immersive(get,never):Bool;
 public static var keepAwake(get,never):Bool;
 public static var safeInsets(get,never):SafeInsets;
 static function get_immersive():Bool return Native.displayImmersive();
 static function get_keepAwake():Bool return Native.displayKeepAwake();
 static function get_safeInsets():SafeInsets {
  var packet = Native.displayInsets();
  return {left:packet.getI32(0),top:packet.getI32(4),right:packet.getI32(8),bottom:packet.getI32(12)};
 }
 public static function setImmersive(value:Bool):Void Native.displaySetImmersive(value);
 public static function setKeepAwake(value:Bool):Void Native.displaySetKeepAwake(value);
}
