import game.GameModel;
class GameEventTest {
    static var count=0;
    static function eq(a:Dynamic,b:Dynamic,n:String) { count++; if(a!=b) throw n+': expected '+b+', got '+a; }
    static function place(m:GameModel,kind:String) { m.entities.push({id:900,kind:kind,x:m.shipX,y:548.,radius:18.,speed:0.}); }
    static function main() {
        var m=new GameModel(7,0); eq(m.takeEvents().length,0,'title silent'); m.start(); m.start(); eq(m.takeEvents().join(','),'start','one start'); eq(m.takeEvents().length,0,'events drained');
        place(m,'energy'); m.update(0.01); eq(m.takeEvents().join(','),'pickup','pickup');
        place(m,'obstacle'); place(m,'obstacle'); m.update(0.01); eq(m.takeEvents().join(','),'hit','one real damage');
        place(m,'obstacle'); m.update(0.01); eq(m.takeEvents().length,0,'invulnerable silent');
        for(hit in 0...2) { for(_ in 0...15){m.entities.resize(0);m.update(0.1);} m.entities.resize(0); place(m,'obstacle');m.update(0.01); }
        eq(m.takeEvents().join(','),'hit,hit,lost','terminal loss follows damage');
        m.update(0.1); eq(m.takeEvents().length,0,'terminal silent'); m.restart(3); eq(m.takeEvents().join(','),'start','restart start');
        for(_ in 0...451) {m.entities.resize(0);m.update(0.1);} eq(m.takeEvents().join(','),'won','single win');
        Sys.println('Events: '+count+' assertions passed');
    }
}
