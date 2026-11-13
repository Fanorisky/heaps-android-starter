package heapsandroid;

/** Typed, versioned JSON preferences. Future schemas are read without rewriting them. */
class Preferences {
    final name:String;
    final schemaVersion:Int;
    var values:Dynamic={};
    var future=false;
    function new(name:String,version:Int) { this.name=name+'.json'; this.schemaVersion=version; }
    static function object(value:Dynamic):Bool return value!=null && Type.typeof(value)==TObject;
    public static function open(name:String,schemaVersion:Int,migrate:(Int,Dynamic)->Dynamic):Preferences {
        if(!Storage.validateRelativePath(name) || schemaVersion<1) throw 'Invalid preferences name or schema version';
        var prefs=new Preferences(name,schemaVersion);
        var bytes=Storage.readFile(prefs.name);
        if(bytes==null) return prefs;
        try {
            var doc:Dynamic=haxe.Json.parse(bytes.toString());
            var version:Dynamic=Reflect.field(doc,'version');
            var data:Dynamic=Reflect.field(doc,'values');
            if(!object(doc) || version==null || !Std.isOfType(version,Int) || version<1 || !object(data)) return prefs;
            if(version>schemaVersion) prefs.future=true;
            else if(version<schemaVersion) data=migrate==null ? {} : migrate(version,data);
            if(object(data)) prefs.values=data;
        } catch(_:Dynamic) {}
        return prefs;
    }
    // HashLink primitive type checks accept null; reject it before unboxing.
    public function getBool(key:String,fallback:Bool):Bool { var v=Reflect.field(values,key); return v!=null && Std.isOfType(v,Bool)?v:fallback; }
    public function getInt(key:String,fallback:Int):Int { var v=Reflect.field(values,key); return v!=null && Std.isOfType(v,Int)?v:fallback; }
    public function getFloat(key:String,fallback:Float):Float {
        var v=Reflect.field(values,key); return (v!=null && Std.isOfType(v,Float) && Math.isFinite(v))?v:fallback;
    }
    public function getString(key:String,fallback:String):String { var v=Reflect.field(values,key); return v!=null && Std.isOfType(v,String)?v:fallback; }
    public function setBool(key:String,value:Bool):Void Reflect.setField(values,key,value);
    public function setInt(key:String,value:Int):Void Reflect.setField(values,key,value);
    public function setFloat(key:String,value:Float):Void { if(Math.isFinite(value)) Reflect.setField(values,key,value); else remove(key); }
    public function setString(key:String,value:String):Void { if(value!=null) Reflect.setField(values,key,value); else remove(key); }
    public function remove(key:String):Void { Reflect.deleteField(values,key); }
    public function commit():Bool {
        if(future) return false;
        return try Storage.writeFileAtomic(name,haxe.io.Bytes.ofString(haxe.Json.stringify({version:schemaVersion,values:values}))) catch(_:Dynamic) false;
    }
}
