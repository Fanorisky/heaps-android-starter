import heapsandroid.Android;
import heapsandroid.Audio;
import heapsandroid.Lifecycle;
import heapsandroid.internal.Native;

/** Android-backed cold-start characterization. Its assertions run in hxd.App.init,
 * before the first MainLoop tick, against genuine lifecycle/JNI/audio services. */
class StartupRegression extends hxd.App {
 override function init():Void {
  var events:Array<Int> = [];
  var unsubscribe = Lifecycle.subscribe(event -> events.push(event));
  try {
   Android.init();
   var snapshot = Native.lifecycleState();
   if((snapshot & 1) == 0) throw "Test must launch in foreground";
   if(!Lifecycle.foreground) throw "Android.init returned before synchronizing foreground";
   if(Lifecycle.focused != ((snapshot & 2) != 0)) throw "Window focus snapshot was not synchronized";
   if(events.length == 0 || events[0] != 0) throw "Initial foreground callback was not dispatched";
   hxd.Res.initEmbed();
   if(!Audio.init()) throw "Real OpenAL device unavailable";
   if(Audio.playMusic(hxd.Res.android.music, true) == null) throw "Cold-start music channel was not created";
   trace("ANDROID_STARTUP_TEST_PASS");
  } catch(error:Dynamic) {
   trace('ANDROID_STARTUP_TEST_FAIL: $error');
  }
  unsubscribe();
 }
 static function main():Void {
  Android.prepare();
  new StartupRegression();
 }
}
