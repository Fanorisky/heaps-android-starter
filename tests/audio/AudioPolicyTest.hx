import heapsandroid.internal.AudioPolicy;
class AudioPolicyTest {
    static function eq(actual:Float, expected:Float) {
        if (actual != expected) throw 'Expected $expected, got $actual';
    }
    static function main() {
        eq(AudioPolicy.clampVolume(-0.2), 0);
        eq(AudioPolicy.clampVolume(2), 1);
        eq(AudioPolicy.clampVolume(0.4), 0.4);
        eq(AudioPolicy.clampVolume(Math.NaN), 0);
        eq(AudioPolicy.clampVolume(Math.POSITIVE_INFINITY), 0);
        eq(AudioPolicy.clampVolume(Math.NEGATIVE_INFINITY), 0);
        eq(AudioPolicy.effectiveVolume(0.5, false, 0.4), 0.2);
        eq(AudioPolicy.effectiveVolume(0.5, true, 0.4), 0);
        eq(AudioPolicy.effectiveVolume(0.5, false, 3), 0.5);
        Sys.println("AUDIO_POLICY_TEST_PASS");
    }
}
