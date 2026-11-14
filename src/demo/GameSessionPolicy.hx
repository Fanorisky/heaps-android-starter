package demo;

/** Gameplay pause ownership; foreground/focus gains never restore user intent. */
class GameSessionPolicy {
    public var featuresOpen(default, null) = false;
    var screenshotMode = false;
    public var paused(get, never):Bool;
    var userPaused = false;
    var foreground = true;
    var focused = true;

    public function new() {}
    function get_paused():Bool return userPaused || featuresOpen || screenshotMode || !foreground || !focused;
    public function reconcile(foreground:Bool, focused:Bool):Void {
        this.foreground = foreground;
        this.focused = focused;
        if (!foreground || !focused) userPaused = true;
    }
    public function pause():Void userPaused = true;
    public function resume():Bool {
        if (!foreground || !focused || featuresOpen || screenshotMode) return false;
        userPaused = false;
        return true;
    }
    public function setFeaturesOpen(open:Bool):Void featuresOpen = open;
    public function setScreenshotMode(enabled:Bool):Void screenshotMode = enabled;
}
