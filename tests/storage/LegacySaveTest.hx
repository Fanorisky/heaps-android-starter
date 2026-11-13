import heapsandroid.Storage;
import heapsandroid.internal.StorageRoots;
import game.GameModel;
class LegacySaveTest {
    static function main() {
        var dir='/tmp/heaps-legacy-'+Std.int(haxe.Timer.stamp()*1000);
        @:privateAccess Storage.roots=new StorageRoots(dir,dir+'/cache');
        var fixture=sys.io.File.getBytes('tests/storage/fixtures/neon-drift-best.sav');
        if(!Storage.writeFileAtomic('neon-drift-best.sav',fixture)) throw 'fixture write failed';
        hxd.Save.readSaveData=function(name) return Storage.readFile(name+'.sav').toString();
        hxd.Save.writeSaveData=function(name,data) { if(!Storage.writeFileAtomic(name+'.sav',haxe.io.Bytes.ofString(data))) throw 'save failed'; };
        if(GameModel.validateBestScore(hxd.Save.load(null,'neon-drift-best',true))!=321) throw 'legacy checksum serializer unreadable';
        hxd.Save.save({version:1,bestScore:322},'neon-drift-best',true);
        if(GameModel.validateBestScore(hxd.Save.load(null,'neon-drift-best',true))!=322) throw 'legacy save roundtrip';
        // The production adapter must retain the established serializer and salted checksum.
        var literal='oy9:bestScorei322y7:versioni1g';
        var checksum=haxe.crypto.Sha1.encode(literal+haxe.crypto.Sha1.encode(literal+'s*al!t')).substr(4,32);
        if(Storage.readFile('neon-drift-best.sav').toString()!=literal+'#'+checksum) throw 'legacy format changed';
        Sys.command('rm',['-rf',dir]); Sys.println('Legacy save: 3 assertions passed');
    }
}
