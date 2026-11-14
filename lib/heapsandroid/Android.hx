package heapsandroid;
import heapsandroid.internal.Native;
/** Call prepare before constructing hxd.App, and init after its window exists. */
class Android {
 static var prepared = false;
 static var initialized = false;
 static var updating = false;
 static var pump:haxe.MainLoop.MainEvent;
 public static function prepare():Void {
  if(prepared) return;
  Native.prepare(); prepared = true;
 }
 public static function init():Void {
  if(initialized) return;
  prepare(); Native.init(); initialized = true;
  Audio.bindToSdk();
  // Startup playback may run before the first MainLoop tick.
  update();
  pump = haxe.MainLoop.add(update, 100); pump.isBlocking = false;
 }
 public static function update():Void {
  if(!initialized || updating) return;
  updating = true;
  try {
   var event = Native.pollLifecycle();
   while(event >= 0) { Lifecycle.ingest(event); if(event == 1) Keyboard.background(); event = Native.pollLifecycle(); }
   Lifecycle.reconcile(Native.lifecycleState());
   Audio.poll();
   Lifecycle.dispatch();
   Keyboard.poll();
  } catch(error:Dynamic) { updating = false; throw error; }
  updating = false;
 }
 public static function shutdown():Void {
  if(!initialized) return;
  initialized = false;
  if(pump != null) {pump.stop(); pump = null;}
  Audio.suspendForSdk();
  Keyboard.hide();
  Sensors.disable(Accelerometer); Sensors.disable(Gyroscope);
  Haptics.cancel(); Native.abandonAudioFocus(); Native.shutdown();
  Lifecycle.reset(); prepared = false;
 }
}
