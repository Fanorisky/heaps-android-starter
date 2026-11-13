import game.GameModel;

class GameModelTest {
    static var failures = 0;
    static var checks = 0;

    static function equal<T>(actual:T, expected:T, description:String):Void {
        checks++;
        if (actual != expected) throw description + ': expected ' + expected + ', got ' + actual;
    }

    static function near(actual:Float, expected:Float, description:String):Void {
        checks++;
        if (Math.isNaN(actual) || Math.abs(actual - expected) > 0.00001)
            throw description + ': expected ' + expected + ', got ' + actual;
    }

    static function test(name:String, body:Void->Void):Void {
        try {
            body();
            Sys.println('PASS ' + name);
        } catch (error:Dynamic) {
            failures++;
            Sys.println('FAIL ' + name + ': ' + Std.string(error));
        }
    }

    // Hand-placed fixtures exercise actual collision rules without test-only model hooks.
    static function place(model:GameModel, kind:String, x:Float, y:Float):Void {
        model.entities.push({id: 900, kind: kind, x: x, y: y, radius: 18, speed: 0});
    }

    static function main():Void {
        test('title waits for an explicit start', function() {
            var m = new GameModel(7, 100);
            m.update(0.1);
            equal(m.phase, 'title', 'initial phase');
            near(m.elapsed, 0, 'title clock');
            equal(m.entities.length, 0, 'title entities');
            m.start();
            equal(m.phase, 'playing', 'start phase');
            equal(m.health, 3, 'starting health');
            equal(m.bestScore, 100, 'loaded best');
        });
        test('steering clamps to visible ship bounds and rejects nonfinite input', function() {
            var m = new GameModel(7, 0);
            m.start();
            m.setShipTargetX(-500);
            for (_ in 0...10) m.update(0.1);
            near(m.shipX, 24, 'left edge');
            m.setShipTargetX(1000);
            for (_ in 0...10) m.update(0.1);
            near(m.shipX, 336, 'right edge');
            m.setShipTargetX(Math.NaN);
            m.update(0.1);
            near(m.shipX, 336, 'NaN input ignored');
            m.setShipTargetX(Math.POSITIVE_INFINITY);
            m.update(0.1);
            near(m.shipX, 336, 'infinite input ignored');
        });
        test('large deltas are capped and invalid deltas do not advance', function() {
            var m = new GameModel(7, 0);
            m.start();
            m.update(1000);
            near(m.elapsed, 0.1, 'capped clock');
            m.update(Math.NaN);
            m.update(Math.POSITIVE_INFINITY);
            m.update(-1);
            m.update(0);
            near(m.elapsed, 0.1, 'invalid deltas');
            near(m.remaining, 44.9, 'remaining time');
        });
        test('pause freezes the run and resume continues it', function() {
            var m = new GameModel(7, 0);
            m.start();
            m.update(0.1);
            place(m, 'energy', 100, 100);
            m.entities[0].speed = 100;
            m.pause();
            equal(m.phase, 'paused', 'pause phase');
            m.update(0.1);
            near(m.elapsed, 0.1, 'paused clock');
            near(m.entities[0].y, 100, 'paused entity');
            m.resume();
            m.update(0.1);
            near(m.elapsed, 0.2, 'resumed clock');
            near(m.entities[0].y, 110, 'resumed entity');
        });
        test('one collision damages once and grants temporary invulnerability', function() {
            var m = new GameModel(7, 0);
            m.start();
            place(m, 'obstacle', 180, 548);
            place(m, 'obstacle', 180, 548);
            m.update(0.01);
            equal(m.health, 2, 'simultaneous hits');
            equal(m.entities.length, 0, 'colliding obstacles removed');
            place(m, 'obstacle', 180, 548);
            m.update(0.01);
            equal(m.health, 2, 'invulnerable hit');
            m.entities.resize(0);
            for (_ in 0...15) m.update(0.1);
            m.entities.resize(0);
            place(m, 'obstacle', m.shipX, 548);
            m.update(0.01);
            equal(m.health, 1, 'damage after grace period');
        });
        test('energy awards points while distant obstacles do not damage', function() {
            var m = new GameModel(7, 0);
            m.start();
            place(m, 'energy', 180, 548);
            place(m, 'obstacle', 30, 548);
            m.update(0.01);
            equal(m.score, 25, 'energy score');
            equal(m.health, 3, 'distant obstacle');
            equal(m.entities.length, 1, 'energy consumed');
        });
        test('third damage ends the run and terminal states freeze', function() {
            var m = new GameModel(7, 0);
            m.start();
            for (hit in 0...3) {
                m.entities.resize(0);
                place(m, 'obstacle', m.shipX, 548);
                m.update(0.01);
                if (hit < 2) {
                    m.entities.resize(0);
                    for (_ in 0...15) m.update(0.1);
                }
            }
            equal(m.phase, 'lost', 'loss phase');
            equal(m.health, 0, 'final health');
            equal(m.bestScore, m.score, 'best after loss');
            var elapsed = m.elapsed;
            var score = m.score;
            m.update(0.1);
            m.pause();
            m.resume();
            m.start();
            equal(m.phase, 'lost', 'terminal phase stable');
            near(m.elapsed, elapsed, 'terminal clock');
            equal(m.score, score, 'terminal score');
        });
        test('surviving forty five seconds wins and records best', function() {
            var m = new GameModel(7, 0);
            m.start();
            for (_ in 0...451) {
                m.entities.resize(0);
                m.update(0.1);
            }
            equal(m.phase, 'won', 'win phase');
            near(m.elapsed, 45, 'final elapsed');
            near(m.remaining, 0, 'remaining');
            equal(m.score, 650, 'survival score and finish bonus');
            equal(m.bestScore, 650, 'best recorded');
        });
        test('restart clears every transient run field while keeping best', function() {
            var m = new GameModel(7, 800);
            m.start();
            m.setShipTargetX(30);
            place(m, 'energy', 180, 548);
            m.update(0.01);
            m.pause();
            m.restart(123);
            equal(m.phase, 'playing', 'restart starts');
            near(m.elapsed, 0, 'restart elapsed');
            near(m.shipX, 180, 'restart ship');
            equal(m.health, 3, 'restart health');
            equal(m.score, 0, 'restart score');
            equal(m.entities.length, 0, 'restart entities');
            equal(m.bestScore, 800, 'restart best');
            near(m.invulnerable, 0, 'restart invulnerability');
        });
        test('spawning is reproducible for a seed and entities expire', function() {
            var a = new GameModel(51, 0);
            var b = new GameModel(51, 0);
            var c = new GameModel(52, 0);
            a.start(); b.start(); c.start();
            for (_ in 0...30) { a.update(0.1); b.update(0.1); c.update(0.1); }
            equal(a.entities.length > 0, true, 'spawns exist');
            equal(haxe.Json.stringify(a.entities), haxe.Json.stringify(b.entities), 'same seed');
            equal(haxe.Json.stringify(a.entities) == haxe.Json.stringify(c.entities), false, 'different seeds');
            a.entities.resize(0);
            place(a, 'obstacle', 30, 700);
            a.update(0.01);
            equal(a.entities.length, 0, 'expired entity');
        });
        test('save validation requires the known version and bounded integer score', function() {
            equal(GameModel.validateBestScore({version: 1, bestScore: 0}), 0, 'zero');
            equal(GameModel.validateBestScore({version: 1, bestScore: 321}), 321, 'score');
            equal(GameModel.validateBestScore({version: 1, bestScore: 1000000}), 1000000, 'upper bound');
            var invalid:Array<Dynamic> = [null, 12, {}, {bestScore: 50}, {version: 2, bestScore: 50},
                {version: 1, bestScore: -1}, {version: 1, bestScore: 1000001},
                {version: 1, bestScore: 1.5}, {version: 1, bestScore: '20'},
                {version: 1, bestScore: Math.NaN}, {version: 1, bestScore: Math.POSITIVE_INFINITY}];
            for (entry in invalid) equal(GameModel.validateBestScore(entry), 0, 'invalid save');
        });
        Sys.println(checks + ' assertions, ' + failures + ' failures');
        if (failures > 0) Sys.exit(1);
    }
}
