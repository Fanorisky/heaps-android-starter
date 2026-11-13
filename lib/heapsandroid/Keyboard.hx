package heapsandroid;
import heapsandroid.internal.Native;
typedef KeyboardRect = {x:Int,y:Int,width:Int,height:Int};
class Keyboard {
 static var cancelPending = false;
 public static var active(get,never):Bool;
 static function get_active():Bool return Native.keyboardActive();
 public static function show(?rect:KeyboardRect):Bool {
  if(rect == null) rect = {x:0,y:0,width:1,height:1};
  return Native.keyboardShow(rect.x,rect.y,rect.width < 1 ? 1 : rect.width,rect.height < 1 ? 1 : rect.height);
 }
 public static function hide():Void Native.keyboardHide();
 @:allow(heapsandroid.Android) static function background():Void cancelPending = true;
 @:allow(heapsandroid.Android) static function poll():Void {
  if(cancelPending) {
   cancelPending = false;
   // Heaps Key tracks presses independently of SDL's keyboard state.
   hxd.Window.getInstance().event(new hxd.Event(EReleaseOutside));
  }
  if(!Lifecycle.foreground && active) hide();
 }
}
