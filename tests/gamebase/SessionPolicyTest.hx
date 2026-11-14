import demo.GameSessionPolicy;

class SessionPolicyTest {
    static function check(value:Bool, message:String) {
        if (!value) throw message;
    }
    static function main() {
        var session = new GameSessionPolicy();
        check(!session.paused, 'Fresh foreground game can run');
        session.setFeaturesOpen(true);
        check(session.paused, 'Feature screen freezes gameplay');
        session.setFeaturesOpen(false);
        check(!session.paused, 'Closing features restores an uninterrupted game');
        session.setFeaturesOpen(true);
        session.reconcile(false, false);
        session.reconcile(true, true);
        session.setFeaturesOpen(false);
        check(session.paused, 'Foreground and closing features cannot undo lifecycle pause');
        check(session.resume(), 'Explicit eligible resume succeeds');
        check(!session.paused, 'Explicit resume releases gameplay');
        session.reconcile(true, false);
        check(!session.resume(), 'Unfocused resume is rejected');
        session.reconcile(true, true);
        check(session.paused, 'Focus gain does not resume');
        session.setFeaturesOpen(true);
        check(!session.resume(), 'Features retain gameplay ownership');
        session.setFeaturesOpen(false);
        check(session.resume(), 'Resume after features close');
        session.pause();
        session.setFeaturesOpen(true);
        session.setFeaturesOpen(false);
        check(session.paused, 'User pause survives a feature screen visit');
        check(session.resume(), 'Clear user pause before screenshot');
        session.setScreenshotMode(true);
        session.reconcile(true, true);
        check(session.paused, 'Screenshot mode owns pause across foreground reconciliation');
        check(!session.resume(), 'Resume cannot override screenshot mode');
        session.setScreenshotMode(false);
        check(!session.paused, 'Leaving screenshot resumes uninterrupted gameplay');
        session.pause();
        session.setScreenshotMode(true);
        session.setScreenshotMode(false);
        check(session.paused, 'Screenshot mode cannot erase user pause');
        Sys.println('GAMEBASE_SESSION_TEST_PASS');
    }
}
