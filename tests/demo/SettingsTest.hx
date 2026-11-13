import demo.DemoSettings;
import heapsandroid.Storage;
import heapsandroid.internal.StorageRoots;
class SettingsTest {
    static function eq(a:Dynamic,b:Dynamic,n:String) { if(a!=b) throw n+': expected '+b+', got '+a; }
    static function main() {
        var dir='/tmp/heaps-settings-'+Std.int(haxe.Timer.stamp()*1000);
        @:privateAccess Storage.roots=new StorageRoots(dir,dir+'/cache');
        var s=new DemoSettings(); eq(s.musicVolume,0.35,'default music'); eq(s.sfxVolume,0.75,'default sfx');
        s.musicVolume=3; s.sfxVolume=-1; s.musicMuted=true; s.sfxMuted=true; s.haptics=false; s.editorText='é中😀'; eq(s.commit(),true,'save');
        s=new DemoSettings(); eq(s.musicVolume,1.,'music clamp'); eq(s.sfxVolume,0.,'sfx clamp'); eq(s.musicMuted,true,'music mute'); eq(s.sfxMuted,true,'sfx mute'); eq(s.haptics,false,'haptics'); eq(s.editorText,'é中😀','editor');
        Sys.command('rm',['-rf',dir]); Sys.println('Settings: 9 assertions passed');
    }
}
