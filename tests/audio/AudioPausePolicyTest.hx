import heapsandroid.internal.AudioPausePolicy;
class AudioPausePolicyTest {
    static function check(value:Bool, message:String) { if (!value) throw message; }
    static function main() {
        // A gate pause must not become the user's requested pause.
        var policy = new AudioPausePolicy(false);
        check(policy.effective(false), "gate freezes an unpaused channel");
        check(!policy.effective(true), "explicit gate resume restores user intent");
        check(policy.request(true, false), "user can pause while gated");
        check(policy.effective(true), "user pause survives gate resume");
        check(policy.request(false, false), "user unpause while gated remains effectively paused");
        check(!policy.effective(true), "explicit resume honors gated user unpause");
        var alreadyPaused = new AudioPausePolicy(true);
        check(alreadyPaused.effective(true), "existing user pause is captured on attach");
        Sys.println("AUDIO_PAUSE_POLICY_TEST_PASS");
    }
}
