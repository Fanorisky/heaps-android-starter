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
