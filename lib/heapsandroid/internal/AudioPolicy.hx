package heapsandroid.internal;

/** Target-independent normalization; no driver or native access. */
class AudioPolicy {
    public static function clampVolume(value:Float):Float {
        if (!Math.isFinite(value)) return 0;
        return value < 0 ? 0 : value > 1 ? 1 : value;
    }
    public static function effectiveVolume(bus:Float, muted:Bool, gain:Float = 1):Float {
        return muted ? 0 : clampVolume(bus) * clampVolume(gain);
    }
}
