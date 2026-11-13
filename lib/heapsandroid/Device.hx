package heapsandroid;
import heapsandroid.internal.Native;
typedef DeviceInfo = {sdk:Int,model:String,supportedAbis:Array<String>,appAbi:String};
class Device {
 public static function info():DeviceInfo {
  var abis = @:privateAccess String.fromUTF8(Native.deviceAbis());
  return {sdk:Native.deviceSdk(),model:@:privateAccess String.fromUTF8(Native.deviceModel()),
   supportedAbis:abis.length == 0 ? [] : abis.split(","),appAbi:@:privateAccess String.fromUTF8(Native.deviceAppAbi())};
 }
}
