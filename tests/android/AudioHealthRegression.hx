#if heapsandroid_audio_fault_tests
import heapsandroid.Audio;
import heapsandroid.Audio.AudioState;
import heapsandroid.Audio.AudioError;
import hxd.res.Sound;
import hxd.snd.Channel;

/** Explicit fault-build fixture. Never included in the published proof build.
    Exercises real AL sources/ALC errors; physical disconnect hardware remains
    unverified. The stopped source models disconnect's processed-buffer state. */
class AudioHealthRegression {
    public static var isRunning(default, null) = false;
    static var channel:Channel;
    static var sample:Sound;
    static var callback:(Bool, String)->Void;
    static var deadline:Float;
    static var position:Float;
    static var stage:Int;
    static function check(value:Bool, detail:String) { if (!value) throw detail; }
    public static function start(sound:Sound, report:(Bool, String)->Void):Void {
        sample = sound; callback = report; isRunning = true;
        // Deliver an observed route change through Audio's real subscriber
        // dispatch from the executing Manager hook. Only this fault fixture
        // invalidates the cached observation; no production route injector.
        var previous = @:privateAccess hxd.snd.Manager.instance;
        var called = false;
        var unsubscribe = Audio.subscribeRouteChanges(function(_) {
            called = true;
            check(Audio.recover(), "Recovery from route callback failed");
        });
        var initialRoute = Audio.routeGeneration;
        // Negative observations are Audio's uninitialized-baseline sentinel.
        // Keep this deliberately unequal fixture observation nonnegative,
        // including the normal startup generation zero.
        var seededRoute = initialRoute == 0 ? 1 : 0;
        @:privateAccess Audio.observedRoute = seededRoute;
        try previous.update() catch (error:Dynamic) {
            unsubscribe();
            Sys.println("AUDIO_HEALTH_ROUTE updateError=" + Std.string(error) + " initial=" + initialRoute
                + " seeded=" + seededRoute + " callback=" + called + " state=" + Audio.state + " error=" + Audio.error);
            throw error;
        }
        unsubscribe();
        var replacement = @:privateAccess hxd.snd.Manager.instance;
        var replaced = replacement != null && replacement != previous;
        var recoveredState = Audio.state;
        var recoveredError = Audio.error;
        Sys.println("AUDIO_HEALTH_ROUTE initial=" + initialRoute + " seeded=" + seededRoute
            + " observed=" + (@:privateAccess Audio.observedRoute) + " callback=" + called
            + " replaced=" + replaced + " state=" + recoveredState + " error=" + recoveredError);
        check(called, "Route subscriber was not called (initial=" + initialRoute + ", seeded=" + seededRoute + ")");
        check(replaced, "Route subscriber did not replace its executing Manager");
        check(recoveredState == Paused && recoveredError == None,
            "Route recovery did not leave healthy paused audio (state=" + recoveredState + ", error=" + recoveredError + ")");
        channel = sample.play(false);
        stage = 0; deadline = haxe.Timer.stamp() + 0.2;
    }
    public static function update():Void {
        if (!isRunning || haxe.Timer.stamp() < deadline) return;
        try {
            switch (stage) {
                case 0:
                    var source = @:privateAccess channel.source;
                    check(source != null && source.playing, "Health fixture lacks a real playing source");
                    position = channel.position;
                    openal.AL.sourceStop(source.handle.inst);
                    check(openal.AL.getSourcei(source.handle.inst, openal.AL.BUFFERS_PROCESSED) > 0, "Stopped-source fixture lacks processed buffers");
                    var manager = @:privateAccess hxd.snd.Manager.instance;
                    var driver:hxd.snd.openal.Driver = cast (@:privateAccess manager.driver);
                    openal.ALC.getIntegerv(driver.device, 0x7fffffff, 1, haxe.io.Bytes.alloc(4));
                    Audio.poll();
                    check(Audio.state == Unavailable && Audio.error == BackendFailure && channel.pause, "Late actual ALC error did not freeze the gate");
                    check(Audio.playSfx(sample) == null && Audio.playMusic(sample) == null, "Wrapper fabricated playback after an output failure");
                    var rawFailed = false;
                    try sample.play(false) catch (error:Dynamic) rawFailed = Std.string(error).indexOf("recover and replay") >= 0;
                    check(rawFailed, "Raw play hid unavailable output");
                    var count = 0; for (active in manager.getAll(sample)) ++count;
                    check(count == 1 && !channel.isReleased(), "Unavailable play leaked a new channel or disposed the recoverable old channel");
                    stage = 1; deadline = haxe.Timer.stamp() + channel.duration + 0.2;
                case 1:
                    check(!channel.isReleased() && channel.pause && Math.abs(channel.position - position) < 0.002, "Failed output consumed completed buffers and expired or moved a paused channel");
                    check(Audio.recover() && channel.isReleased() && Audio.state == Paused, "Health recovery did not recreate a fresh paused Manager");
                    var replay = sample.play(true); check(!replay.pause && Audio.state == Running, "Explicit replay after failure recovery denied"); replay.stop();
                    finish(true, "Late real ALC error with processed source buffers stays frozen until explicit recreation/replay (hardware unverified)");
            }
        } catch (error:Dynamic) { finish(false, Std.string(error)); }
    }
    static function finish(ok:Bool, detail:String):Void {
        isRunning = false;
        if (channel != null && !channel.isReleased()) channel.stop();
        var report = callback; callback = null; channel = null; sample = null;
        if (report != null) report(ok, detail);
    }
}
#end
