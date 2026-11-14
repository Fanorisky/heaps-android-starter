import hxd.snd.Channel;
import hxd.snd.ChannelGroup;
import hxd.snd.Manager;
import hxd.snd.SoundGroup;

/** CPU unit tests of the actual patched Heaps classes; no playback claim. */
@:access(hxd.snd.Channel)
@:access(hxd.snd.ChannelBase)
@:access(hxd.snd.Manager)
class HeapsAudioHooksTest {
    static function check(value:Bool, detail:String):Void { if (!value) throw detail; }
    static function channel():Channel {
        var value = new Channel();
        value.channelGroup = new ChannelGroup("test");
        value.soundGroup = new SoundGroup("test");
        return value;
    }
    static function disposedManagerUpdate():Void {
        // Disposing/replacing the executing Manager in its update callback
        // must prevent all further processing of its cleared source arrays.
        var previous = Type.createEmptyInstance(Manager);
        previous.timeOffset = 1;
        previous.channels = null;
        previous.driver = null;
        previous.updateEvent = haxe.MainLoop.add(function() {});
        var replacement = Type.createEmptyInstance(Manager);
        Manager.instance = previous;
        Manager.heapsAndroidBeforeUpdate = function() {
            previous.dispose();
            Manager.instance = replacement;
        };
        previous.update();
        check(Manager.instance == replacement, "Disposed Manager update changed its replacement");
        Manager.instance = null;
        Manager.heapsAndroidBeforeUpdate = null;
    }
    static function main():Void {
        #if js
        if (js.Syntax.code("process.argv.includes('manager-only')")) { disposedManagerUpdate(); return; }
        #end
        var value = channel();
        var completed = false;
        value.pause = true;
        value.fadeTo(0, 0.1, function() completed = true);
        value.calcAudibleVolume(haxe.Timer.stamp() + 2);
        check(!completed && value.volume == 1, "Paused fade ran its callback or changed volume");

        // A halfway-completed fade must continue from halfway after pause.
        value.pause = false;
        var stamp = haxe.Timer.stamp();
        value.fadeTo(0, 0.1, function() completed = true);
        value.currentFade.start = stamp - 0.05;
        value.calcAudibleVolume(stamp);
        check(Math.abs(value.volume - 0.5) < 0.001, "Fade fixture is not halfway complete");
        value.pause = true;
        // Fast-forward only the fixture's stored pause boundary. No sleeps.
        Reflect.setField(value, "heapsAndroidPauseStamp", haxe.Timer.stamp() - 2);
        value.currentFade.start -= 2;
        value.calcAudibleVolume(stamp + 1);
        check(!completed && Math.abs(value.volume - 0.5) < 0.001, "Pause advanced an existing fade");
        value.pause = false;
        var resumed = haxe.Timer.stamp();
        value.calcAudibleVolume(resumed + 0.02);
        check(!completed && value.volume > 0.25 && value.volume < 0.35, "Resume restarted or skipped the remaining fade");
        value.calcAudibleVolume(resumed + 0.06);
        check(completed, "Resumed fade never completed");

        // Starting a fade partway through a long user pause must retain its
        // full duration on resume, even though the pause began before it.
        var created = channel();
        created.pause = true;
        var createdCompleted = false;
        created.fadeTo(0, 0.1, function() createdCompleted = true);
        Reflect.setField(created, "heapsAndroidPauseStamp", haxe.Timer.stamp() - 3);
        created.currentFade.start -= 2;
        created.calcAudibleVolume(haxe.Timer.stamp());
        check(!createdCompleted && created.volume == 1, "Fade created during pause advanced");
        created.pause = false;
        var started = haxe.Timer.stamp();
        created.calcAudibleVolume(started + 0.02);
        check(!createdCompleted && created.volume > 0.75 && created.volume < 0.85, "New paused fade lost its full remaining duration");
        created.calcAudibleVolume(started + 0.11);
        check(createdCompleted, "New paused fade did not complete after resume");

        // Manager timeOffset already shifts all audio clocks; keep the pause
        // boundary in the same clock domain instead of excluding time twice.
        var offset = channel();
        offset.fadeTo(0, 0.1);
        var offsetStamp = haxe.Timer.stamp();
        offset.currentFade.start = offsetStamp - 0.05;
        offset.calcAudibleVolume(offsetStamp);
        offset.pause = true;
        Reflect.setField(offset, "heapsAndroidPauseStamp", haxe.Timer.stamp() - 2);
        offset.currentFade.start -= 2;
        var shifted = Type.createEmptyInstance(Manager);
        shifted.channels = offset;
        shifted.sources = [];
        shifted.driver = null;
        shifted.timeOffset = 2;
        offset.manager = shifted;
        Manager.instance = shifted;
        shifted.update();
        offset.pause = false;
        offset.calcAudibleVolume(haxe.Timer.stamp() + 0.02);
        check(offset.volume > 0.25 && offset.volume < 0.35, "Manager clock offset was counted twice during pause");
        Manager.instance = null;

        disposedManagerUpdate();
        #if sys
        Sys.println("HEAPS_AUDIO_HOOKS_TEST_PASS (CPU only; playback unverified)");
        #else
        js.Syntax.code("console.log('HEAPS_AUDIO_HOOKS_TEST_PASS (CPU only; playback unverified)'); process.exit(0)");
        #end
    }
}
