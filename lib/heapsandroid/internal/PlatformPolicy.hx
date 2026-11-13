package heapsandroid.internal;
/** Pure normalization shared by platform APIs and their host tests. */
class PlatformPolicy {
 public static function orientationHint(value:String):String {
  return switch value {
   case "portrait": "Portrait PortraitUpsideDown";
   case "landscape": "LandscapeLeft LandscapeRight";
   case "unspecified": "";
   default: throw 'Invalid Android orientation: $value';
  }
 }
 public static inline function hapticDuration(milliseconds:Int):Int {
  return milliseconds < 1 ? 1 : milliseconds > 2000 ? 2000 : milliseconds;
 }
}
