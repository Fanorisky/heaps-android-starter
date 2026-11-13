import heapsandroid.Storage;
import heapsandroid.Preferences;
import heapsandroid.internal.StorageRoots;
import haxe.io.Bytes;

class StorageTest {
    static var count = 0;
    static function eq(a:Dynamic,b:Dynamic,name:String) { count++; if(a != b) throw name + ': expected '+b+', got '+a; }
    static function main() {
        var base = '/tmp/heaps-storage-' + Std.int(haxe.Timer.stamp()*1000);
        if(!sys.FileSystem.exists(base)) sys.FileSystem.createDirectory(base);
        @:privateAccess Storage.roots = new StorageRoots(base+'/files',base+'/cache');
        for(p in ['', '/absolute', '../x', './x', 'a/../x', 'a/./x', 'a\\x', 'x\x00y', 'C:/x', 'a//x'])
            eq(Storage.validateRelativePath(p),false,'reject '+p);
        eq(Storage.validateRelativePath('folder/settings.json'),true,'nested path');
        eq(Storage.writeFileAtomic('folder/data',Bytes.ofString('first')),true,'first write');
        eq(Storage.writeFileAtomic('folder/data',Bytes.ofString('second')),true,'replace');
        eq(Storage.readFile('folder/data').toString(),'second','atomic replacement');
        eq(Storage.readFile('../files/folder/data'),null,'traversal read');
        eq(Storage.writeCacheAtomic('data',Bytes.ofString('cached')),true,'cache write');
        eq(Storage.readCache('data').toString(),'cached','cache separated');
        eq(Storage.readFile('data'),null,'cache not files');
        // Existing symlink outside the configured root must never be followed.
        Sys.command('ln',['-s',base,base+'/files/escape']);
        eq(Storage.writeFileAtomic('escape/outside',Bytes.ofString('bad')),false,'canonical escape');
        eq(Storage.readFile('escape/cache/data'),null,'canonical read escape');
        eq(Storage.deleteFile('folder/data'),true,'delete');
        eq(Storage.readFile('folder/data'),null,'deleted');
        var p = Preferences.open('settings',1,function(_,data) return data);
        p.setBool('enabled',true); p.setInt('score',23); p.setFloat('volume',0.4); p.setString('text','é中😀');
        eq(p.commit(),true,'commit');
        p = Preferences.open('settings',1,function(_,data) return data);
        eq(p.getBool('enabled',false),true,'bool reload'); eq(p.getInt('score',0),23,'int reload');
        eq(p.getFloat('volume',1),0.4,'float reload'); eq(p.getString('text',''),'é中😀','string reload');
        eq(p.getInt('enabled',9),9,'strict bool to int'); eq(p.getBool('score',false),false,'strict int to bool');
        eq(p.getString('score','fallback'),'fallback','strict int to string');
        p.setFloat('bad',Math.NaN); eq(p.getFloat('bad',0.7),0.7,'reject NaN');
        p.remove('score'); p.commit(); eq(Preferences.open('settings',1,function(_,d)return d).getInt('score',17),17,'remove');
        Storage.writeFileAtomic('corrupt.json',Bytes.ofString('{broken'));
        p = Preferences.open('corrupt',1,function(_,data)return data); eq(p.getBool('a',true),true,'corrupt fallback');
        p.setBool('a',false); eq(p.commit(),true,'corrupt replaced');
        Storage.writeFileAtomic('old.json',Bytes.ofString('{"version":1,"values":{"legacy":7,"extra":"keep"}}'));
        p = Preferences.open('old',2,function(version,data) { eq(version,1,'migration source'); Reflect.setField(data,'new',Reflect.field(data,'legacy')+1); return data; });
        eq(p.getInt('new',0),8,'migration result'); eq(p.getString('extra',''),'keep','unknown value preserved'); eq(p.commit(),true,'migration commit');
        Storage.writeFileAtomic('future.json',Bytes.ofString('{"version":9,"values":{"value":13},"future":"untouched"}'));
        p = Preferences.open('future',1,function(_,_) { throw 'must not migrate future'; return null; }); eq(p.getInt('value',0),13,'future readable');
        p.setInt('value',2); eq(p.commit(),false,'future no downgrade');
        eq(Storage.readFile('future.json').toString(),'{"version":9,"values":{"value":13},"future":"untouched"}','future original intact');
        Storage.writeFileAtomic('wrong.json',Bytes.ofString('{"version":1,"values":{"b":"true","i":2.5,"s":false,"f":"0.5"}}'));
        p=Preferences.open('wrong',1,function(_,d)return d); eq(p.getBool('b',false),false,'typed bool'); eq(p.getInt('i',8),8,'typed integer'); eq(p.getString('s','x'),'x','typed string'); eq(p.getFloat('f',0.2),0.2,'typed float');
        // A destination directory prevents rename; the old entry survives and temp files are removed.
        sys.FileSystem.createDirectory(base+'/files/blocked');
        eq(Storage.writeFileAtomic('blocked',Bytes.ofString('bad')),false,'failed rename');
        eq(sys.FileSystem.readDirectory(base+'/files').filter(n->n.indexOf('.tmp-')>=0).length,0,'temporary cleanup');
        Sys.println('Storage: '+count+' assertions passed');
        Sys.command('rm',['-rf',base]);
    }
}
