import heapsandroid.Preferences;
import heapsandroid.Storage;
import haxe.io.Bytes;

/** Same real preferences checks on Android/HashLink and the interpreter. */
class PreferencesRegression {
    static function equal(actual:Dynamic,expected:Dynamic,description:String):Void {
        if(actual != expected) throw description + ': expected ' + expected + ', got ' + actual;
    }
    public static function run():Bool {
        var name='heaps-preferences-selfcheck-'+Std.int(haxe.Timer.stamp()*1000000);
        var file=name+'.json';
        var passed=false;
        var owned=false;
        var message='';
        try {
            if(Storage.readFile(file)!=null) throw 'Temporary preferences name already exists';
            owned=true;
            var p=Preferences.open(name,1,function(_,data)return data);
            equal(p.getBool('missing',true),true,'missing bool fallback');
            equal(p.getInt('missing',37),37,'missing integer fallback');
            equal(p.getFloat('missing',0.35),0.35,'missing float fallback');
            equal(p.getString('missing','Hello Heaps'),'Hello Heaps','missing string fallback');
            if(!Storage.writeFileAtomic(file,Bytes.ofString('{"version":1,"values":{"b":null,"i":null,"f":null,"s":null}}')))
                throw 'Null fixture write failed';
            p=Preferences.open(name,1,function(_,data)return data);
            equal(p.getBool('b',true),true,'null bool fallback');
            equal(p.getInt('i',37),37,'null integer fallback');
            equal(p.getFloat('f',0.75),0.75,'null float fallback');
            equal(p.getString('s','Hello Heaps'),'Hello Heaps','null string fallback');
            p.setBool('b',false);p.setInt('i',0);p.setFloat('f',0);
            if(!p.commit()) throw 'Typed preferences commit failed';
            p=Preferences.open(name,1,function(_,data)return data);
            equal(p.getBool('b',true),false,'saved false remains false');
            equal(p.getInt('i',37),0,'saved integer zero remains zero');
            equal(p.getFloat('f',0.75),0.,'saved float zero remains zero');
            if(!Storage.writeFileAtomic(file,Bytes.ofString('{"version":null,"values":{"volume":0.9}}')))
                throw 'Schema fixture write failed';
            p=Preferences.open(name,1,function(_,data)return data);
            equal(p.getFloat('volume',0.35),0.35,'null schema fallback');
            passed=true;message='missing/null defaults and typed zero/false persisted';
        } catch(error:Dynamic) { message=Std.string(error); }
        if(owned) Storage.deleteFile(file);
        Sys.println((passed ? 'PREFS_TEST_PASS ' : 'PREFS_TEST_FAIL ') + message);
        return passed;
    }
    static function main():Void { if(!run()) Sys.exit(1); }
}
