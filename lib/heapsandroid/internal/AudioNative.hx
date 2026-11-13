package heapsandroid.internal;

/** Native gate, called exclusively from the Heaps thread. */
@:hlNative("heapsandroid", "audio_")
extern class AudioNative {
    public static function registerDevice(device:openal.ALC.Device):Int;
    public static function unregisterDevice():Void;
    public static function setIntent(intent:Bool):Void;
    public static function getState():Int;
}
