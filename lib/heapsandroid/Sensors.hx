package heapsandroid;
import heapsandroid.internal.Native;
import heapsandroid.internal.SensorPacket;
enum abstract SensorKind(Int) from Int to Int {var Accelerometer=0; var Gyroscope=1;}
typedef SensorSample = heapsandroid.internal.SensorPacket.SamplePacket;
class Sensors {
 public static function available(kind:SensorKind):Bool return Native.sensorAvailable(kind);
 public static function enable(kind:SensorKind):Bool return Native.sensorEnable(kind);
 public static function disable(kind:SensorKind):Void Native.sensorDisable(kind);
 public static function sample(kind:SensorKind):Null<SensorSample> {
  var packet = Native.sensorSample(kind);
  return packet == null ? null : SensorPacket.decode(@:privateAccess new haxe.io.Bytes(packet,32));
 }
}
