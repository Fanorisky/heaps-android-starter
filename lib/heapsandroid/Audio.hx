package heapsandroid;

import heapsandroid.internal.AudioNative;
import heapsandroid.internal.AudioPolicy;
import heapsandroid.internal.Native;
import hxd.res.Sound;
import hxd.snd.Channel;
import hxd.snd.Manager;

enum abstract AudioState(Int) from Int to Int {
    var Unavailable = 0;
    var Paused = 1;
    var Running = 2;
}

private class OwnedChannel {
    public var channel:Channel;
    public var gain:Float;
    public var pausedByGate = false;
    public function new(channel:Channel, gain:Float) {
        this.channel = channel; this.gain = gain;
    }
}

/** Standard Heaps channels, guarded by Android foreground and AudioManager focus.
    Call Android.init() to install the pump before Heaps' sound-manager updates. */
@:access(hxd.snd.Manager)
class Audio {
    public static var state(get, never):AudioState;
    public static var sfxVolume(default, set):Float = 1;
    public static var musicVolume(default, set):Float = 1;
    public static var sfxMuted(default, set):Bool = false;
    public static var musicMuted(default, set):Bool = false;
    static var manager:Manager;
    static var music:OwnedChannel;
    static var sfx:Array<OwnedChannel> = [];
    static var initialized = false;

    public static function init():Bool {
        if (initialized) return AudioNative.getState() != 0;
        var candidate:Manager = null;
        try {
            candidate = Manager.get();
            var driver = candidate.driver;
            if (!Std.isOfType(driver, hxd.snd.openal.Driver)) {
                cleanupFailed(candidate); return false;
            }
            var openal:hxd.snd.openal.Driver = cast driver;
            if (openal.device == null || openal.context == null
                || AudioNative.registerDevice(openal.device) != 1) {
                cleanupFailed(candidate); return false;
            }
            manager = candidate;
            initialized = true;
            poll();
            return true;
        } catch (error:Dynamic) {
            cleanupFailed(candidate);
            return false;
        }
    }
    static function cleanupFailed(candidate:Manager):Void {
        Native.abandonAudioFocus();
        AudioNative.unregisterDevice();
        // Manager's constructor may fail after creating its driver/sources.
        // Driver construction itself is guarded by the checked upstream patch.
        if (candidate != null && candidate == Manager.instance) candidate.dispose();
        initialized = false; manager = null;
    }
    static function get_state():AudioState {
        return initialized ? cast AudioNative.getState() : Unavailable;
    }
    public static function poll():Void {
        if (!initialized) return;
        var running = AudioNative.getState() == Running;
        manager.suspended = !running;
        if (music != null) {
            if (music.channel.isReleased()) music = null;
            else reconcileChannel(music, running);
        }
        var index = 0;
        while (index < sfx.length) {
            var owned = sfx[index];
            if (owned.channel.isReleased()) sfx.splice(index, 1);
            else { reconcileChannel(owned, running); ++index; }
        }
    }
    static function reconcileChannel(owned:OwnedChannel, running:Bool):Void {
        if (!running) {
            if (!owned.channel.pause) {
                owned.channel.pause = true;
                owned.pausedByGate = true;
            }
        } else if (owned.pausedByGate) {
            // Assign only on this transition: Heaps' setter resets lastStamp.
            owned.channel.pause = false;
            owned.pausedByGate = false;
        }
    }
    public static function playSfx(sound:Sound, volume:Float = 1):Null<Channel> {
        if (sound == null || !resume()) return null;
        var gain = AudioPolicy.clampVolume(volume);
        var channel = sound.play(false, AudioPolicy.effectiveVolume(sfxVolume, sfxMuted, gain));
        channel.mute = sfxMuted;
        sfx.push(new OwnedChannel(channel, gain));
        poll();
        return channel;
    }
    public static function playMusic(sound:Sound, loop:Bool = true):Null<Channel> {
        if (sound == null || !resume()) return null;
        stopMusic();
        var channel = sound.play(loop, AudioPolicy.effectiveVolume(musicVolume, musicMuted));
        channel.mute = musicMuted;
        music = new OwnedChannel(channel, 1);
        poll();
        return channel;
    }
    public static function stopMusic():Void {
        if (music != null) music.channel.stop();
        music = null;
    }
    public static function pause():Void {
        AudioNative.setIntent(false);
        Native.abandonAudioFocus();
        poll();
    }
    /** Foreground/focus recovery alone does not resume playback. */
    public static function resume():Bool {
        if (!init()) return false;
        if (AudioNative.getState() == Running) { poll(); return true; }
        if (!Lifecycle.foreground || !Native.requestAudioFocus()) {
            AudioNative.setIntent(false); Native.abandonAudioFocus(); poll(); return false;
        }
        AudioNative.setIntent(true);
        var running = AudioNative.getState() == Running;
        if (!running) { AudioNative.setIntent(false); Native.abandonAudioFocus(); }
        poll();
        return running;
    }
    public static function shutdown():Void {
        if (!initialized) return;
        pause(); stopMusic();
        for (owned in sfx) owned.channel.stop();
        sfx = [];
        // Native callbacks cannot touch the device once unregister returns.
        AudioNative.unregisterDevice();
        var previous = manager;
        initialized = false; manager = null;
        if (previous == Manager.instance) previous.dispose();
    }
    static function set_sfxVolume(value:Float):Float {
        sfxVolume = AudioPolicy.clampVolume(value); updateSfxVolumes(); return sfxVolume;
    }
    static function set_musicVolume(value:Float):Float {
        musicVolume = AudioPolicy.clampVolume(value); updateMusicVolume(); return musicVolume;
    }
    static function set_sfxMuted(value:Bool):Bool {
        sfxMuted = value; updateSfxVolumes(); return value;
    }
    static function set_musicMuted(value:Bool):Bool {
        musicMuted = value; updateMusicVolume(); return value;
    }
    static function updateSfxVolumes():Void {
        for (owned in sfx) if (!owned.channel.isReleased()) {
            owned.channel.volume = AudioPolicy.effectiveVolume(sfxVolume, sfxMuted, owned.gain);
            owned.channel.mute = sfxMuted;
        }
    }
    static function updateMusicVolume():Void {
        if (music != null && !music.channel.isReleased()) {
            music.channel.volume = AudioPolicy.effectiveVolume(musicVolume, musicMuted);
            music.channel.mute = musicMuted;
        }
    }
}
