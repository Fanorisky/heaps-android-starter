import heapsandroid.internal.PlatformPolicy;
import heapsandroid.internal.LifecycleStore;
import heapsandroid.internal.SensorPacket;
import heapsandroid.Lifecycle.LifecycleEvent;
class PlatformTest {
 static var checks = 0;
 static function eq(actual:Dynamic, expected:Dynamic) { checks++; if(actual != expected) throw 'expected $expected, got $actual'; }
 static function main() {
  eq(PlatformPolicy.orientationHint("portrait"), "Portrait PortraitUpsideDown");
  eq(PlatformPolicy.orientationHint("landscape"), "LandscapeLeft LandscapeRight");
  eq(PlatformPolicy.orientationHint("unspecified"), "");
  eq(PlatformPolicy.hapticDuration(-9), 1); eq(PlatformPolicy.hapticDuration(0), 1);
  eq(PlatformPolicy.hapticDuration(85), 85); eq(PlatformPolicy.hapticDuration(9000), 2000);
  var state = new LifecycleStore(); var seen = [];
  var remove = state.subscribe(e -> seen.push(e));
  state.ingest(0); state.ingest(0); state.ingest(2);
  eq(seen.length, 0); state.dispatch(); eq(seen.join(","), "0,2");
  eq(state.foreground, true); eq(state.focused, true);
  remove(); remove(); state.ingest(1); state.dispatch(); eq(seen.length, 2);
  eq(state.foreground, false);
  var second:Void->Void = null;
  state.subscribe(e -> { if(second != null) second(); });
  second = state.subscribe(e -> seen.push(e));
  state.ingest(0); state.dispatch(); eq(seen.length, 2);
  // Native overflow can discard an older foreground event; its latest snapshot repairs state.
  var recovered = new LifecycleStore(); var recovery = [];
  recovered.subscribe(e -> recovery.push(e)); recovered.reconcile(3); recovered.dispatch();
  eq(recovered.foreground, true); eq(recovered.focused, true); eq(recovery.join(","), "0,2");
  recovered.reconcile(3); recovered.dispatch(); eq(recovery.length, 2);
  var overflow = new LifecycleStore(); var overflowEvents = [];
  overflow.subscribe(e -> overflowEvents.push(e)); overflow.ingest(0);
  for(i in 0...1000) overflow.ingest(i % 2 == 0 ? 2 : 3);
  overflow.reconcile(1); overflow.dispatch();
  eq(overflowEvents[0], 0); eq(overflowEvents.length, 32);
  var focusOverflow = new LifecycleStore(); var focusEvents = [];
  focusOverflow.subscribe(e -> focusEvents.push(e)); focusOverflow.ingest(2);
  for(i in 0...1000) focusOverflow.ingest(i % 2 == 0 ? 0 : 1);
  focusOverflow.reconcile(2); focusOverflow.dispatch(); eq(focusEvents[0], 2);
  var interrupted = new LifecycleStore(); var interruptedEvents:Array<Int> = [];
  interrupted.subscribe(event -> {
   interruptedEvents.push(event);
   if((event:Int) == 0) interrupted.reset();
  });
  interrupted.ingest(0); interrupted.ingest(2); interrupted.dispatch();
  eq(interruptedEvents.join(","), "0,1,3");
  var restarting = new LifecycleStore(); var restartEvents:Array<Int> = [];
  restarting.subscribe(event -> {
   restartEvents.push(event);
   if((event:Int) == 1) { restarting.beginSession(); restarting.reconcile(3); restarting.dispatch(); }
  });
  restarting.reconcile(3); restarting.dispatch(); restartEvents = [];
  restarting.reset();
  eq(restartEvents.join(","), "1,0,2");
  eq(restarting.foreground, true); eq(restarting.focused, true);
  var resetPending = new LifecycleStore(); var afterReset:Array<Int> = [];
  resetPending.subscribe(event -> afterReset.push(event));
  resetPending.ingest(0); resetPending.ingest(2); resetPending.reset();
  eq(afterReset.join(","), "1,3");
  eq(resetPending.foreground, false); eq(resetPending.focused, false);
  // SDK shutdown resets lifecycle state, while subscriptions survive a same-Activity restart.
  var sdkEvents:Array<Int> = [];
  var unsubscribeSdk = heapsandroid.Lifecycle.subscribe(event -> sdkEvents.push(event));
  @:privateAccess heapsandroid.Lifecycle.ingest(0);
  @:privateAccess heapsandroid.Lifecycle.dispatch();
  @:privateAccess heapsandroid.Lifecycle.reset();
  @:privateAccess heapsandroid.Lifecycle.ingest(0);
  @:privateAccess heapsandroid.Lifecycle.dispatch();
  eq(sdkEvents[sdkEvents.length-1], 0); eq(sdkEvents.length, 3);
  unsubscribeSdk();
  var b = haxe.io.Bytes.alloc(32);
  b.setDouble(0, 1.5); b.setDouble(8, -2.25); b.setDouble(16, 0.125);
  b.setInt32(24, 0x89ABCDEF); b.setInt32(28, 0x12345678);
  var sample = SensorPacket.decode(b);
  eq(sample.x, 1.5); eq(sample.y, -2.25); eq(sample.z, 0.125);
  eq(sample.timestampNs.high, 0x12345678); eq(sample.timestampNs.low, 0x89ABCDEF);
  eq(SensorPacket.decode(haxe.io.Bytes.alloc(31)), null);
  Sys.println('Platform pure checks: $checks');
 }
}
