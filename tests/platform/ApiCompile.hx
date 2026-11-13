import heapsandroid.*;
/** Compile-only use of every public host API against genuine Heaps/HL types. */
class ApiCompile {
 static function main() {
  Android.prepare(); Android.init(); Android.update();
  var unsubscribe = Lifecycle.subscribe(e -> trace(e));
  trace(Lifecycle.foreground); trace(Lifecycle.focused); unsubscribe();
  Keyboard.show({x:1,y:2,width:30,height:40}); trace(Keyboard.active); Keyboard.hide();
  trace(Haptics.available); Haptics.enabled=false; Haptics.vibrate(30); Haptics.cancel();
  Sensors.enable(Accelerometer); Sensors.disable(Gyroscope); trace(Sensors.available(Gyroscope)); trace(Sensors.sample(Accelerometer));
  Display.setImmersive(false); Display.setKeepAwake(false); trace(Display.immersive); trace(Display.keepAwake); trace(Display.safeInsets);
  trace(Device.info()); trace(heapsandroid.internal.Native.filesPath()); trace(heapsandroid.internal.Native.cachePath());
  Android.shutdown();
 }
}
