package heapsandroid;

import heapsandroid.internal.AudioNative;
import heapsandroid.internal.AudioPolicy;
import heapsandroid.internal.AudioPausePolicy;
import heapsandroid.internal.Native;
import hxd.res.Sound;
import hxd.snd.Channel;
import hxd.snd.Manager;

enum abstract AudioState(Int) from Int to Int {
    var Unavailable = 0;
    var Paused = 1;
    var Running = 2;
}
enum abstract AudioError(Int) from Int to Int {
    var None = 0;
    var NoDevice = 1;
    var Unsupported = 2;
    var Disconnected = 3;
    var BackendFailure = 4;
    var ResumeFailure = 5;
}
private class OwnedChannel {
    public var channel:Channel;
    public var gain:Float;
    public function new(channel:Channel, gain:Float) { this.channel = channel; this.gain = gain; }
}

/** Android gate for every raw or wrapped Heaps channel. Android.init installs
    the conditional Manager hooks before updates and attaches existing channels.
    Gains never restore playback intent; call resume or explicitly play again. */
@:access(hxd.snd.Manager)
@:access(hxd.snd.Channel)
class Audio {
    public static var state(get, never):AudioState;
    public static var error(get, never):AudioError;
    public static var routeGeneration(get, never):Int;
    public static var sfxVolume(default, set):Float = 1;
    public static var musicVolume(default, set):Float = 1;
    public static var sfxMuted(default, set):Bool = false;
    public static var musicMuted(default, set):Bool = false;
    static var manager:Manager;
    static var music:OwnedChannel;
    static var sfx:Array<OwnedChannel> = [];
    static var channels = new haxe.ds.ObjectMap<Channel, AudioPausePolicy>();
    static var initialized = false;
    static var sdkActive = false;
    static var gateRunning = false;
    static var internalPauseDepth = 0;
    static var wrapperDepth = 0;
    static var localError:AudioError = NoDevice;
    static var observedRoute = -1;
    static var routeListeners:Array<Int->Void> = [];

    /** SDK start does not grant focus or intent, even for an existing Manager. */
    public static function bindToSdk():Void {
        sdkActive = true;
        installHooks();
        // Baseline the route snapshot; startup is not a route change.
        if (observedRoute < 0) observedRoute = Native.routeGeneration();
        if (Manager.instance != null && Manager.instance != manager) attach(Manager.instance);
        poll();
    }
    /** Reversible SDK stop: preserve the Manager, device and channel positions. */
    public static function suspendForSdk():Void {
        sdkActive = false;
        pause();
    }
    static function installHooks():Void {
        #if heapsandroid_audio_hooks
        Manager.heapsAndroidAfterCreate = attach;
        Manager.heapsAndroidAfterPlay = afterPlay;
        Manager.heapsAndroidBeforeUpdate = poll;
        Manager.heapsAndroidBeforeDispose = beforeDispose;
        Manager.heapsAndroidFilterPause = filterPause;
        #end
    }
    static function attach(candidate:Manager):Void {
        if (candidate == manager) return;
        manager = candidate;
        initialized = gateRunning = false;
        channels = new haxe.ds.ObjectMap();
        localError = NoDevice;
        if (Std.isOfType(candidate.driver, hxd.snd.openal.Driver)) {
            var driver:hxd.snd.openal.Driver = cast candidate.driver;
            if (driver.device != null && driver.context != null) {
                initialized = AudioNative.registerDevice(driver.device) == 1;
                localError = cast AudioNative.getError();
            }
        } else if (candidate.driver != null) localError = Unsupported;
        captureChannels();
        reconcileChannels(false);
    }
    public static function init():Bool {
        installHooks();
        if (initialized) return AudioNative.getState() != Unavailable;
        var candidate:Manager = null;
        try {
            candidate = Manager.get();
            if (candidate != manager) attach(candidate);
            if (!initialized) {
                var failure = localError;
                disposeManager(); localError = failure;
                return false;
            }
            poll();
            return AudioNative.getState() != Unavailable;
        } catch (failure:Dynamic) {
            disposeManager(); localError = BackendFailure;
            return false;
        }
    }
    static function get_state():AudioState {
        poll();
        return initialized ? cast AudioNative.getState() : Unavailable;
    }
    static function get_error():AudioError {
        poll();
        return initialized ? cast AudioNative.getError() : localError;
    }
    static inline function get_routeGeneration():Int return Native.routeGeneration();
    /** Dispatch runs in poll on the Haxe thread, never an Android callback. */
    public static function subscribeRouteChanges(callback:Int->Void):Void->Void {
        if (callback == null) throw "Route callback is required";
        routeListeners.push(callback);
        var subscribed = true;
        return function() {
            if (subscribed) { subscribed = false; routeListeners.remove(callback); }
        };
    }
    public static function poll():Void {
        var nativeState:AudioState = initialized ? cast AudioNative.getState() : Unavailable;
        gateRunning = sdkActive && nativeState == Running;
        captureChannels();
        reconcileChannels(gateRunning);
        if (nativeState == Unavailable && manager != null && manager.sources != null) {
            // Disconnection can mark queued buffers processed. Detach before
            // Manager.update consumes them and expires/resets paused channels.
            // Keep the last synchronized channel position. Normal pauses still
            // let Manager capture the final device sample offset as before.
            for (source in manager.sources) if (source.channel != null) manager.releaseSource(source);
        }
        if (music != null && music.channel.isReleased()) music = null;
        var index = 0;
        while (index < sfx.length) {
            if (sfx[index].channel.isReleased()) sfx.splice(index, 1); else ++index;
        }
        if (sdkActive) {
            var route = Native.routeGeneration();
            if (observedRoute < 0) observedRoute = route;
            else if (route != observedRoute) {
                observedRoute = route;
                for (callback in routeListeners.copy()) if (routeListeners.indexOf(callback) >= 0) callback(route);
            }
        }
    }
    static function captureChannels():Void {
        if (manager == null) return;
        var channel = manager.channels;
        while (channel != null) {
            if (!channels.exists(channel)) channels.set(channel, new AudioPausePolicy(channel.pause));
            channel = channel.next;
        }
    }
    static function reconcileChannels(running:Bool):Void {
        if (manager != null) manager.suspended = !running;
        for (channel in channels.keys()) {
            if (channel.isReleased()) { channels.remove(channel); continue; }
            var effective = channels.get(channel).effective(running);
            if (channel.pause != effective) {
                ++internalPauseDepth;
                channel.pause = effective;
                --internalPauseDepth;
            }
        }
    }
    static function filterPause(channel:Channel, requested:Bool):Bool {
        if (internalPauseDepth > 0) return requested;
        if (channel.isReleased()) return requested;
        var policy = channels.get(channel);
        if (policy == null) { policy = new AudioPausePolicy(channel.pause); channels.set(channel, policy); }
        gateRunning = initialized && sdkActive && AudioNative.getState() == Running;
        return policy.request(requested, gateRunning);
    }
    static inline function eligible():Bool return sdkActive && Lifecycle.foreground && Lifecycle.focused;
    static function afterPlay(channel:Channel):Void {
        channels.set(channel, new AudioPausePolicy(channel.pause));
        // Sound.play returns only after this hook. First raw play is explicit
        // intent; subsequent Running plays avoid repeated AudioManager requests.
        if (wrapperDepth == 0 && eligible()) {
            if (!initialized || AudioNative.getState() == Unavailable) {
                channel.stop(); channels.remove(channel);
                throw "Audio unavailable; recover and replay";
            }
            resume();
            if (AudioNative.getState() == Unavailable) {
                channel.stop(); channels.remove(channel);
                throw "Audio unavailable; recover and replay";
            }
        }
        poll();
    }
    static function beforeDispose(candidate:Manager):Void {
        if (candidate != manager) return;
        AudioNative.setIntent(false);
        Native.abandonAudioFocus();
        AudioNative.unregisterDevice();
        initialized = gateRunning = false;
        manager = null; music = null; sfx = [];
        channels = new haxe.ds.ObjectMap();
        localError = NoDevice;
    }
    public static function playSfx(sound:Sound, volume:Float = 1):Null<Channel> {
        if (sound == null || !resume()) return null;
        var gain = AudioPolicy.clampVolume(volume);
        var channel:Channel;
        ++wrapperDepth;
        try channel = sound.play(false, AudioPolicy.effectiveVolume(sfxVolume, sfxMuted, gain))
        catch (failure:Dynamic) { --wrapperDepth; poll(); return null; }
        --wrapperDepth;
        channel.mute = sfxMuted;
        sfx.push(new OwnedChannel(channel, gain));
        poll(); return channel;
    }
    public static function playMusic(sound:Sound, loop:Bool = true):Null<Channel> {
        if (sound == null || !resume()) return null;
        stopMusic();
        var channel:Channel;
        ++wrapperDepth;
        try channel = sound.play(loop, AudioPolicy.effectiveVolume(musicVolume, musicMuted))
        catch (failure:Dynamic) { --wrapperDepth; poll(); return null; }
        --wrapperDepth;
        channel.mute = musicMuted;
        music = new OwnedChannel(channel, 1);
        poll(); return channel;
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
    public static function resume():Bool {
        if (!eligible()) { pause(); return false; }
        if (!init()) return false;
        if (AudioNative.getState() == Running) { poll(); return true; }
        if (!Native.requestAudioFocus()) { pause(); return false; }
        AudioNative.setIntent(true);
        var running = AudioNative.getState() == Running;
        if (!running) { AudioNative.setIntent(false); Native.abandonAudioFocus(); }
        poll(); return running;
    }
    /** One actual device/context recreation attempt. All channels returned
        before recovery are released and must be replayed explicitly. Success
        returns Paused, without requesting AudioManager focus or playback intent. */
    public static function recover():Bool {
        pause();
        disposeManager();
        return init();
    }
    static function disposeManager():Void {
        var previous = manager;
        if (previous == null) previous = Manager.instance;
        AudioNative.setIntent(false); Native.abandonAudioFocus();
        AudioNative.unregisterDevice();
        if (previous != null && previous == Manager.instance) previous.dispose();
        initialized = gateRunning = false; manager = null;
        music = null; sfx = []; channels = new haxe.ds.ObjectMap();
        localError = NoDevice;
    }
    /** Terminal audio disposal. Android.shutdown uses suspendForSdk instead. */
    public static function shutdown():Void {
        pause(); disposeManager();
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
