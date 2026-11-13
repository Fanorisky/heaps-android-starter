import heapsandroid.Audio;
import heapsandroid.Audio.AudioState;
import hxd.res.Sound;
import hxd.snd.Channel;

/** Android-backed checks with actual packaged sounds, Manager and Channels.
    update() never blocks and must be called from the application's update. */
class AudioRegression {
    public static var isRunning(default, null) = false;
    static var sound:Sound;
    static var report:(Bool, String)->Void;
    static var channel:Channel;
    static var stage = 0;
    static var deadline:Float;
    static var position:Float;
    static var savedVolume:Float;
    static var savedMuted:Bool;
    static var savedSfxVolume:Float;
    static var savedSfxMuted:Bool;
    static var testSfx:Array<Channel>;
    static var virtualCase:Bool;

    public static function start(sample:Sound, callback:(Bool, String)->Void):Void {
        if (isRunning) { callback(false, "Audio checks already running"); return; }
        sound = sample; report = callback;
        savedVolume = Audio.musicVolume; savedMuted = Audio.musicMuted;
        savedSfxVolume = Audio.sfxVolume; savedSfxMuted = Audio.sfxMuted;
        testSfx = [];
        isRunning = true; virtualCase = false;
        try {
            if (!Audio.init()) { finish(false, "OpenAL device unavailable"); return; }
            if (!checkSfxVolumes()) { finish(false, "SFX bus did not update live/future channels"); return; }
            Audio.musicVolume = 0.5; Audio.musicMuted = false;
            begin();
        } catch (error:Dynamic) { finish(false, Std.string(error)); }
    }
    static function begin():Void {
        var previous = channel;
        channel = Audio.playMusic(sound, true);
        if (channel == null) { finish(false, "Playback/focus denied"); return; }
        if (previous != null && !previous.isReleased()) { finish(false, "Music replacement left previous loop alive"); return; }
        if (channel.duration < 0.2) { finish(false, "Regression sample must be at least 0.2 seconds"); return; }
        stage = 0; deadline = haxe.Timer.stamp() + 0.25;
    }
    static function checkSfxVolumes():Bool {
        Audio.sfxMuted = false; Audio.sfxVolume = 0.5;
        var first = Audio.playSfx(sound, 0.4);
        if (first == null) return false;
        testSfx.push(first);
        if (Math.abs(first.volume - 0.2) > 0.00001) return false;
        Audio.sfxVolume = 0.25;
        if (Math.abs(first.volume - 0.1) > 0.00001) return false;
        Audio.sfxMuted = true;
        if (!first.mute || first.volume != 0) return false;
        var second = Audio.playSfx(sound, 0.4);
        if (second == null) return false;
        testSfx.push(second);
        if (!second.mute || second.volume != 0) return false;
        Audio.sfxMuted = false;
        if (second.mute || Math.abs(second.volume - 0.1) > 0.00001) return false;
        for (ch in testSfx) ch.stop();
        return true;
    }
    static function advanced(previous:Float, current:Float):Bool {
        var delta = current - previous;
        if (delta < 0) delta += channel.duration;
        return delta > 0.015;
    }
    public static function update():Void {
        if (!isRunning) return;
        try {
            Audio.poll();
            var now = haxe.Timer.stamp();
            if (now < deadline) return;
            if (channel == null || channel.isReleased()) { finish(false, "Loop channel released"); return; }
            switch (stage) {
                case 0:
                    if (Audio.state != Running || channel.pause) { finish(false, "Channel did not start"); return; }
                    if (virtualCase != @:privateAccess channel.isVirtual) {
                        finish(false, virtualCase ? "Muted loop did not become virtual" : "Audible loop stayed virtual"); return;
                    }
                    if (!virtualCase && !hasPlayingSource()) { finish(false, "No playing OpenAL source"); return; }
                    Audio.musicVolume = 0.25;
                    if (channel.mute != virtualCase || channel.volume != (virtualCase ? 0 : 0.25)) {
                        finish(false, "Music volume/mute did not update existing channel"); return;
                    }
                    position = channel.position; stage = 1; deadline = now + 0.11;
                case 1:
                    if (!advanced(position, channel.position)) { finish(false, "Loop position did not advance"); return; }
                    Audio.pause();
                    if (!channel.pause || Audio.state != Paused) { finish(false, "Pause did not freeze channel"); return; }
                    // Manager first syncs the actual sample offset and releases
                    // the paused source. Measure from that final device offset.
                    stage = 2; deadline = now + 0.05;
                case 2:
                    position = channel.position; stage = 5; deadline = now + 0.35;
                case 5:
                    if (Math.abs(channel.position - position) > 0.002) { finish(false, "Paused loop position advanced with wall time"); return; }
                    if (!Audio.resume()) { finish(false, "Explicit resume denied"); return; }
                    if (channel.pause || Math.abs(channel.position - position) > 0.002) { finish(false, "Resume reset position or kept pause"); return; }
                    stage = 3; deadline = now + 0.11;
                case 3:
                    if (!advanced(position, channel.position)) { finish(false, "Resumed loop position did not advance"); return; }
                    if (!virtualCase) {
                        virtualCase = true; Audio.musicMuted = true; begin();
                    } else {
                        // A user-paused channel must stay paused through gate transitions.
                        channel.pause = true; position = channel.position;
                        Audio.pause();
                        if (!Audio.resume() || !channel.pause) { finish(false, "Gate erased user pause"); return; }
                        stage = 4; deadline = now + 0.2;
                    }
                case 4:
                    if (Math.abs(channel.position - position) > 0.002) { finish(false, "User pause did not preserve position"); return; }
                    finish(true, "Audible OpenAL source and muted virtual loop: progress, pause, preserved position, explicit resume, user pause");
            }
        } catch (error:Dynamic) { finish(false, Std.string(error)); }
    }
    static function hasPlayingSource():Bool {
        var source = @:privateAccess channel.source;
        return source != null && source.playing
            && openal.AL.getSourcei(source.handle.inst, openal.AL.SOURCE_STATE) == openal.AL.PLAYING;
    }
    static function finish(passed:Bool, detail:String):Void {
        isRunning = false;
        if (testSfx != null) for (ch in testSfx) ch.stop();
        Audio.stopMusic(); Audio.musicVolume = savedVolume; Audio.musicMuted = savedMuted;
        Audio.sfxVolume = savedSfxVolume; Audio.sfxMuted = savedSfxMuted;
        var callback = report; report = null; channel = null; sound = null;
        if (callback != null) callback(passed, detail);
    }
}
