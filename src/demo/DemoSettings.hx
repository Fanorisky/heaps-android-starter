package demo;
import heapsandroid.Preferences;
/** Persisted settings for the SDK proof screen, independent of GameBase. */
class DemoSettings {
    var preferences:Preferences;
    public var musicVolume(get,set):Float;
    public var sfxVolume(get,set):Float;
    public var musicMuted:Bool;
    public var sfxMuted:Bool;
    public var haptics:Bool;
    public var editorText:String;
    var music:Float;
    var sfx:Float;
    public function new() {
        preferences=Preferences.open('heaps-android-settings',1,function(_,_)return {});
        musicVolume=preferences.getFloat('musicVolume',0.35);
        sfxVolume=preferences.getFloat('sfxVolume',0.75);
        musicMuted=preferences.getBool('musicMuted',false);
        sfxMuted=preferences.getBool('sfxMuted',false);
        haptics=preferences.getBool('haptics',true);
        editorText=preferences.getString('editorText','Hello Heaps');
    }
    static function clamp(v:Float):Float return Math.isFinite(v)?Math.max(0,Math.min(1,v)):0;
    function get_musicVolume():Float return music;
    function set_musicVolume(v:Float):Float return music=clamp(v);
    function get_sfxVolume():Float return sfx;
    function set_sfxVolume(v:Float):Float return sfx=clamp(v);
    public function commit():Bool {
        preferences.setFloat('musicVolume',music); preferences.setFloat('sfxVolume',sfx);
        preferences.setBool('musicMuted',musicMuted); preferences.setBool('sfxMuted',sfxMuted);
        preferences.setBool('haptics',haptics); preferences.setString('editorText',editorText);
        return preferences.commit();
    }
}
