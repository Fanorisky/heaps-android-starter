package game;

typedef Entity = {
    var id:Int;
    var kind:String;
    var x:Float;
    var y:Float;
    var radius:Float;
    var speed:Float;
}

class GameModel {
    public static inline var WIDTH = 360;
    public static inline var HEIGHT = 640;
    public static inline var SHIP_Y = 548;
    public static inline var SHIP_RADIUS = 12;
    public static inline var DURATION = 45.0;
    static inline var MAX_BEST = 1000000;

    public var phase(default, null):String = 'title';
    public var elapsed(default, null):Float = 0;
    public var remaining(default, null):Float = 45;
    public var shipX(default, null):Float = 180;
    public var health(default, null):Int = 3;
    public var score(default, null):Int = 0;
    public var bestScore(default, null):Int = 0;
    public var invulnerable(default, null):Float = 0;
    public var entities(default, null):Array<Entity> = [];

    var randomState:Int;
    var targetX:Float = 180;
    var nextObstacle:Float = 0.65;
    var nextEnergy:Float = 1.7;
    var nextId:Int = 0;
    var energyScore:Int = 0;

    public function new(seed:Int, bestScore:Int) {
        randomState = seed == 0 ? 0x13579b : seed;
        this.bestScore = bestScore >= 0 && bestScore <= MAX_BEST ? bestScore : 0;
    }

    public function start():Void {
        if (phase == 'title') phase = 'playing';
    }

    public function setShipTargetX(x:Float):Void {
        if (phase == 'playing' && Math.isFinite(x)) targetX = Math.max(24, Math.min(336, x));
    }

    public function update(dt:Float):Void {
        if (phase != 'playing' || !Math.isFinite(dt) || dt <= 0) return;
        dt = Math.min(dt, 0.1);
        dt = Math.min(dt, DURATION - elapsed);
        elapsed = Math.min(DURATION, elapsed + dt);
        remaining = Math.max(0, DURATION - elapsed);
        invulnerable = Math.max(0, invulnerable - dt);
        var previousShipX = shipX;
        var step = 480 * dt;
        shipX += Math.max(-step, Math.min(step, targetX - shipX));

        nextObstacle -= dt;
        nextEnergy -= dt;
        if (nextObstacle <= 0) {
            spawn('obstacle');
            nextObstacle += 0.72 - 0.30 * elapsed / DURATION;
        }
        if (nextEnergy <= 0) {
            spawn('energy');
            nextEnergy += 2.2;
        }

        var index = entities.length;
        while (index-- > 0) {
            var entity = entities[index];
            var previousY = entity.y;
            entity.y += entity.speed * dt;
            // Test the relative motion segment, so quick drags cannot tunnel through a hazard.
            var relativeX = entity.x - previousShipX;
            var relativeY = previousY - SHIP_Y;
            var deltaX = previousShipX - shipX;
            var deltaY = entity.y - previousY;
            var lengthSquared = deltaX * deltaX + deltaY * deltaY;
            var t = lengthSquared == 0 ? 0 : Math.max(0, Math.min(1,
                -(relativeX * deltaX + relativeY * deltaY) / lengthSquared));
            var dx = relativeX + deltaX * t;
            var dy = relativeY + deltaY * t;
            var radius = SHIP_RADIUS + entity.radius;
            if (dx * dx + dy * dy < radius * radius) {
                entities.splice(index, 1);
                if (entity.kind == 'energy') energyScore += 25;
                else if (invulnerable <= 0) {
                    health--;
                    invulnerable = 1.2;
                }
            } else if (entity.y - entity.radius > HEIGHT) entities.splice(index, 1);
        }
        score = energyScore + Std.int(elapsed * 10 + 0.000001);
        if (health <= 0) finish('lost');
        else if (remaining <= 0.000001) {
            elapsed = DURATION;
            remaining = 0;
            score = energyScore + 650;
            finish('won');
        }
    }

    public function pause():Void {
        if (phase == 'playing') {
            phase = 'paused';
            targetX = shipX;
        }
    }

    public function resume():Void {
        if (phase == 'paused') phase = 'playing';
    }

    public function restart(seed:Int):Void {
        randomState = seed == 0 ? 0x13579b : seed;
        phase = 'playing';
        elapsed = 0;
        remaining = DURATION;
        shipX = targetX = 180;
        health = 3;
        score = energyScore = 0;
        invulnerable = 0;
        entities = [];
        nextId = 0;
        nextObstacle = 0.65;
        nextEnergy = 1.7;
    }

    function finish(result:String):Void {
        phase = result;
        targetX = shipX;
        bestScore = Std.int(Math.min(MAX_BEST, Math.max(bestScore, score)));
    }

    function random():Float {
        randomState ^= randomState << 13;
        randomState ^= randomState >>> 17;
        randomState ^= randomState << 5;
        return (randomState & 0x7fffffff) / 2147483648.0;
    }

    function spawn(kind:String):Void {
        var isEnergy = kind == 'energy';
        var radius = isEnergy ? 10.0 : 17 + random() * 9;
        entities.push({id: nextId++, kind: kind, x: 28 + random() * 304,
            y: -30, radius: radius, speed: isEnergy ? 170 : 170 + random() * 75 + elapsed * 1.2});
    }

    public static function validateBestScore(value:Dynamic):Int {
        if (value == null || !Reflect.isObject(value) || Std.isOfType(value, Array)) return 0;
        var version:Dynamic = Reflect.field(value, 'version');
        var best:Dynamic = Reflect.field(value, 'bestScore');
        if (!Std.isOfType(version, Int) || version != 1 || !Std.isOfType(best, Int)) return 0;
        var result:Int = best;
        return result >= 0 && result <= MAX_BEST ? result : 0;
    }
}
