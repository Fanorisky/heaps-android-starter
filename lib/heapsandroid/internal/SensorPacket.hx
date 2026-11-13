package heapsandroid.internal;
typedef SamplePacket = { x:Float, y:Float, z:Float, timestampNs:haxe.Int64 };
class SensorPacket {
 public static function decode(bytes:haxe.io.Bytes):Null<SamplePacket> {
  if(bytes == null || bytes.length != 32) return null;
  return {x:bytes.getDouble(0), y:bytes.getDouble(8), z:bytes.getDouble(16),
   timestampNs:haxe.Int64.make(bytes.getInt32(28), bytes.getInt32(24))};
 }
}
