import heapsandroid.Android;
import heapsandroid.Audio;
import heapsandroid.Audio.AudioState;
import heapsandroid.Audio.AudioError;
import hxd.res.Sound;
import hxd.snd.Channel;

/** Real Heaps channels and OpenAL in the Android regression build; no fake
    playback or hardware-route assertions. Called after wrapper regressions. */
class RawAudioRegression {
    public static var isRunning(default, null) = false;
    static var sample:Sound;
    static var callback:(Bool, String)->Void;
    static var audible:Channel;
    static var muted:Channel;
    static var userPaused:Channel;
    static var stopped:Channel;
    static var finite:Channel;
    static var positions:Array<Float>;
    static var deadline:Float;
    static var stage:Int;
    static function check(value:Bool, detail:String):Void { if (!value) throw detail; }
    public static function start(sound:Sound, report:(Bool, String)->Void):Void {
        sample = sound; callback = report; isRunning = true;
        try {
            // Creating through raw Sound.play must attach the Manager hooks.
            Audio.shutdown();
            audible = sound.play(true);
            muted = sound.play(true, 0); muted.mute = true;
            userPaused = sound.play(true); userPaused.pause = true;
            check(Audio.state == Running && !audible.pause && !muted.pause, "Raw explicit play did not grant playback intent");
            check(hxd.snd.Manager.heapsAndroidBeforeUpdate != null, "Manager hook not installed");
            stage = 0; deadline = haxe.Timer.stamp() + 0.2;
        } catch (error:Dynamic) { finish(false, Std.string(error)); }
    }
    public static function update():Void {
        if (!isRunning) return;
        #if heapsandroid_audio_fault_tests
        if (stage == 6) { AudioHealthRegression.update(); return; }
        #end
        try {
            Audio.poll();
            var now = haxe.Timer.stamp(); if (now < deadline) return;
            switch (stage) {
                case 0:
                    check(!audible.isReleased() && !muted.isReleased(), "Raw loop prematurely released");
                    check(!(@:privateAccess audible.isVirtual) && (@:privateAccess muted.isVirtual), "Raw audible/virtual fixture did not reach backend");
                    var source = @:privateAccess audible.source;
                    check(source != null && source.playing && openal.AL.getSourcei(source.handle.inst, openal.AL.SOURCE_STATE) == openal.AL.PLAYING, "Raw audible channel has no playing AL source");
                    finite = sample.play(false, 0); finite.mute = true;
                    Audio.pause();
                    // Toggle both directions while gated: the effective pause
                    // must stay true without erasing the user's latest request.
                    audible.pause = true; audible.pause = false;
                    muted.pause = true; muted.pause = false;
                    finite.pause = true; finite.pause = false;
                    userPaused.pause = false; userPaused.pause = true;
                    check(audible.pause && muted.pause && userPaused.pause, "Gated setter allowed unpause");
                    stage = 1; deadline = now + 0.05;
                case 1:
                    positions = [audible.position, muted.position, userPaused.position, finite.position];
                    stage = 2; deadline = now + Math.max(audible.duration, muted.duration) + 0.2;
                case 2:
                    frozen();
                    check(Audio.resume(), "Explicit resume denied");
                    check(!audible.pause && !muted.pause && userPaused.pause, "Gate resume erased requested pause");
                    stage = 3; deadline = now + 0.15;
                case 3:
                    check(advanced(audible, positions[0]) && advanced(muted, positions[1]), "Raw channels did not advance after explicit resume");
                    check(Math.abs(userPaused.position - positions[2]) < 0.002, "Requested pause advanced");
                    Android.shutdown();
                    stopped = sample.play(true, 0); stopped.mute = true;
                    check(stopped.pause && audible.pause && Audio.state == Paused, "SDK stop did not freeze raw channels");
                    stage = 4; deadline = now + 0.05;
                case 4:
                    positions = [audible.position, muted.position, userPaused.position, finite.position, stopped.position];
                    stage = 5; deadline = now + sample.getData().duration + 0.2;
                case 5:
                    frozen(); check(!stopped.isReleased() && Math.abs(stopped.position - positions[4]) < 0.002, "Stopped raw play expired or advanced");
                    Android.init();
                    check(Audio.state == Paused && audible.pause && stopped.pause, "SDK restart restored intent");
                    check(Audio.resume(), "Resume after SDK restart denied");
                    check(!stopped.pause && userPaused.pause, "Restart lost channel user pause");
                    // recover must create a real new device/context, invalidate
                    // every raw and wrapper handle, and leave intent off.
                    var wrapper = Audio.playSfx(sample);
                    check(wrapper != null, "Recovery wrapper fixture failed");
                    check(Audio.recover(), "Explicit device recreation failed");
                    check(audible.isReleased() && muted.isReleased() && userPaused.isReleased() && stopped.isReleased() && finite.isReleased() && wrapper.isReleased(), "Recovery retained stale channels");
                    check(Audio.state == Paused && Audio.error == None, "Recovery granted intent or retained error");
                    var manager = @:privateAccess hxd.snd.Manager.instance;
                    check((@:privateAccess manager.channels) == null, "Recovery alone created channels");
                    var replay = sample.play(true); check(!replay.pause && Audio.state == Running, "Raw explicit replay after recovery denied"); replay.stop();
                    #if heapsandroid_audio_fault_tests
                    stage = 6;
                    AudioHealthRegression.start(sample, function(ok, detail) finish(ok, detail));
                    #else
                    finish(true, "Raw audible/muted loops freeze beyond duration; gated user pause, SDK stop/restart and real paused recovery invalidate all old channels");
                    #end
            }
        } catch (error:Dynamic) { finish(false, Std.string(error)); }
    }
    static function advanced(channel:Channel, previous:Float):Bool {
        var delta = channel.position - previous; if (delta < 0) delta += channel.duration;
        return delta > 0.015;
    }
    static function frozen():Void {
        var channels = [audible, muted, userPaused, finite];
        for (i in 0...channels.length) check(!channels[i].isReleased() && channels[i].pause && Math.abs(channels[i].position - positions[i]) < 0.002, "Raw gated channel advanced or expired");
    }
    static function finish(ok:Bool, detail:String):Void {
        isRunning = false;
        for (ch in [audible, muted, userPaused, finite, stopped]) if (ch != null && !ch.isReleased()) ch.stop();
        var report = callback; callback = null; sample = null;
        audible = muted = userPaused = finite = stopped = null;
        if (report != null) report(ok, detail);
    }
}
