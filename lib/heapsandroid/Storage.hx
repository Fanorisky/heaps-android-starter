package heapsandroid;

import haxe.io.Bytes;
import heapsandroid.internal.StorageRoots;
import sys.FileSystem;
import sys.io.File;

/** Private file/cache storage. Relative names never resolve outside their root. */
class Storage {
    static var roots:StorageRoots;
    static var temporaryId=0;
    static function provider():StorageRoots {
        if(roots==null) {
            #if (android && hl)
            roots=new StorageRoots(heapsandroid.internal.Native.filesPath(),heapsandroid.internal.Native.cachePath());
            #else
            roots=new StorageRoots('.heaps-android','.heaps-android/cache');
            #end
        }
        return roots;
    }
    public static function validateRelativePath(path:String):Bool {
        if(path==null || path.length==0 || path.indexOf('\x00')>=0 || path.indexOf('\\')>=0 || path.indexOf(':')>=0 || StringTools.startsWith(path,'/')) return false;
        for(part in path.split('/')) if(part=='' || part=='.' || part=='..') return false;
        return true;
    }
    static function ensureDirectory(path:String):Void {
        if(FileSystem.exists(path)) { if(!FileSystem.isDirectory(path)) throw 'Storage root is not a directory'; return; }
        var parent=haxe.io.Path.directory(path);
        if(parent!='' && parent!=path) ensureDirectory(parent);
        FileSystem.createDirectory(path);
    }
    static function within(path:String,root:String):Bool {
        return path==root || StringTools.startsWith(path,root+'/');
    }
    static function resolve(name:String,cache:Bool,create:Bool):String {
        if(!validateRelativePath(name)) throw 'Invalid relative storage path';
        var root=cache ? provider().cache : provider().files;
        if(create) ensureDirectory(root);
        if(!FileSystem.exists(root)) throw 'Storage root missing';
        root=FileSystem.fullPath(root);
        var path=root+'/'+name;
        var existing=path;
        while(!FileSystem.exists(existing)) {
            var parent=haxe.io.Path.directory(existing);
            if(parent==existing || parent=='') throw 'Invalid storage parent';
            existing=parent;
        }
        if(!within(FileSystem.fullPath(existing),root)) throw 'Storage path escapes root';
        if(create) {
            ensureDirectory(haxe.io.Path.directory(path));
            if(!within(FileSystem.fullPath(haxe.io.Path.directory(path)),root)) throw 'Storage parent escapes root';
        }
        return path;
    }
    static function read(name:String,cache:Bool):Null<Bytes> {
        return try File.getBytes(resolve(name,cache,false)) catch(_:Dynamic) null;
    }
    static function write(name:String,data:Bytes,cache:Bool):Bool {
        if(data==null) return false;
        var temporary:Null<String>=null;
        var output:Null<sys.io.FileOutput>=null;
        try {
            var path=resolve(name,cache,true);
            do temporary=path+'.tmp-'+Std.int(haxe.Timer.stamp()*1000000)+'-'+temporaryId++ while(FileSystem.exists(temporary));
            output=File.write(temporary,true); output.write(data); output.flush(); output.close(); output=null;
            // Revalidate the destination immediately before replacement.
            resolve(name,cache,false);
            FileSystem.rename(temporary,path);
            return true;
        } catch(_:Dynamic) {
            if(output!=null) try output.close() catch(_:Dynamic) {}
            if(temporary!=null) try if(FileSystem.exists(temporary)) FileSystem.deleteFile(temporary) catch(_:Dynamic) {}
            return false;
        }
    }
    public static function readFile(name:String):Null<Bytes> return read(name,false);
    public static function writeFileAtomic(name:String,data:Bytes):Bool return write(name,data,false);
    public static function deleteFile(name:String):Bool {
        return try { FileSystem.deleteFile(resolve(name,false,false)); true; } catch(_:Dynamic) false;
    }
    public static function readCache(name:String):Null<Bytes> return read(name,true);
    public static function writeCacheAtomic(name:String,data:Bytes):Bool return write(name,data,true);
}
