import game.GameModel;
import h2d.Graphics;
import h2d.Object;
import h2d.Text;
import hxd.Event;

class Main extends hxd.App {
    static inline var CYAN = 0x65edff;
    static inline var PINK = 0xff587f;
    static inline var LIME = 0xc4ff83;
    static inline var WHITE = 0xe4f4ff;
    static inline var MUTED = 0x7693ad;
    static inline var SAVE_NAME = 'neon-drift-best';

    var model:GameModel;
    var background:Graphics;
    var world:Graphics;
    var hud:Object;
    var hudShapes:Graphics;
    var panel:Object;
    var input:h2d.Interactive;
    var scoreText:Text;
    var timeText:Text;
    var hintText:Text;
    var saveWarning:Text;
    var pointerId:Int = -1;
    var phaseShown:String = '';
    var visualTime:Float = 0;
    var savedBest:Int = 0;
    var saveReady:Bool = false;
    var saveFailed:Bool = false;

    #if android
    @:hlNative('std', 'sys_special')
    private static function nativePath(key:hl.Bytes):hl.Bytes { return null; }
    #end

    override function init():Void {
        engine.backgroundColor = 0x07101e;
        s2d.scaleMode = LetterBox(360, 640);
        hxd.Window.getInstance().title = 'Neon Drift';
        hxd.Timer.smoothFactor = 0;
        hxd.Timer.maxDeltaTime = 0.1;
        configureStorage();
        // A null default prevents hxd.Save's field upgrade from accepting an unversioned save.
        var stored:Dynamic = saveReady ? hxd.Save.load(null, SAVE_NAME, true) : null;
        savedBest = GameModel.validateBestScore(stored);
        model = new GameModel(newSeed(), savedBest);

        background = new Graphics(s2d);
        world = new Graphics(s2d);
        hud = new Object(s2d);
        hudShapes = new Graphics(hud);
        label(hud, 'SCORE', 30, 28, 0.65, MUTED);
        scoreText = label(hud, '0000', 30, 44, 1.45, WHITE);
        label(hud, 'TIME', 196, 28, 0.65, MUTED);
        timeText = label(hud, '45', 195, 44, 1.45, CYAN);
        hintText = centered(hud, 'DRAG LEFT / RIGHT', 608, 0.68, MUTED);
        saveWarning = centered(hud, '', 626, 0.6, PINK);
        panel = new Object(s2d);
        input = new h2d.Interactive(360, 640, s2d);
        input.cursor = Default;
        input.onPush = onPush;
        input.onMove = function(event) {
            if (model.phase == 'playing' && pointerId == event.touchId)
                model.setShipTargetX(event.relX);
        };
        input.onRelease = function(event) { if (event.touchId == pointerId) clearPointer(); };
        input.onReleaseOutside = function(event) { if (event.touchId == pointerId) clearPointer(); };
        hxd.Window.getInstance().addEventTarget(onWindowEvent);
        renderPhase();
        draw();
    }

    function configureStorage():Void {
        try {
            var directory:String;
            #if android
            var bytes = nativePath(@:privateAccess 'android_internal_storage_path'.toUtf8());
            if (bytes == null) throw 'Android private storage is unavailable';
            directory = @:privateAccess String.fromUTF8(bytes);
            if (directory == null || directory.length == 0) throw 'Android private storage is empty';
            #else
            directory = '.neon-drift';
            if (!sys.FileSystem.exists(directory)) sys.FileSystem.createDirectory(directory);
            #end
            var path = directory + '/' + SAVE_NAME + '.sav';
            hxd.Save.readSaveData = function(_) return sys.io.File.getContent(path);
            hxd.Save.writeSaveData = function(_, data) {
                var temporary = path + '.tmp';
                try {
                    sys.io.File.saveContent(temporary, data);
                    sys.FileSystem.rename(temporary, path);
                } catch (error:Dynamic) {
                    try if (sys.FileSystem.exists(temporary)) sys.FileSystem.deleteFile(temporary) catch (_:Dynamic) {}
                    throw error;
                }
            };
            saveReady = true;
        } catch (error:Dynamic) {
            saveFailed = true;
            Sys.println('Neon Drift: best score storage unavailable: ' + Std.string(error));
        }
    }

    function persistBest():Void {
        if (model.bestScore <= savedBest) return;
        if (!saveReady) {
            saveFailed = true;
            return;
        }
        try {
            hxd.Save.save({version: 1, bestScore: model.bestScore}, SAVE_NAME, true);
            savedBest = model.bestScore;
            saveFailed = false;
            Sys.println('Neon Drift: best saved ' + savedBest);
        } catch (error:Dynamic) {
            saveFailed = true;
            Sys.println('Neon Drift: best score save failed: ' + Std.string(error));
        }
    }

    function newSeed():Int {
        return Std.int((haxe.Timer.stamp() * 1000) % 2147483647);
    }

    function clearPointer():Void {
        pointerId = -1;
        if (input != null) input.preventClick();
    }

    function onWindowEvent(event:Event):Void {
        switch (event.kind) {
            case EFocusLost:
                clearPointer();
                model.pause();
                hxd.Timer.reset();
                renderPhase();
            case EFocus:
                clearPointer();
                hxd.Timer.reset();
            case ERelease, EReleaseOutside:
                if (event.touchId == pointerId) clearPointer();
            case EKeyDown:
                if (event.keyCode == hxd.Key.ESCAPE || event.keyCode == hxd.Key.P) {
                    if (model.phase == 'playing') pauseRun();
                    else if (model.phase == 'paused') resumeRun();
                } else if (event.keyCode == hxd.Key.ENTER || event.keyCode == hxd.Key.SPACE) {
                    if (model.phase == 'title') startRun();
                    else if (model.phase == 'paused') resumeRun();
                    else if (model.phase == 'won' || model.phase == 'lost') restartRun();
                }
            default:
        }
    }

    static function inside(x:Float, y:Float, left:Float, top:Float, width:Float, height:Float):Bool {
        return x >= left && x <= left + width && y >= top && y <= top + height;
    }

    function onPush(event:Event):Void {
        if (pointerId != -1) return;
        var x = event.relX;
        var y = event.relY;
        switch (model.phase) {
            case 'title':
                if (inside(x, y, 40, 450, 280, 54)) startRun();
            case 'playing':
                if (inside(x, y, 292, 21, 44, 44)) pauseRun();
                else {
                    pointerId = event.touchId;
                    model.setShipTargetX(x);
                }
            case 'paused':
                if (inside(x, y, 48, 368, 264, 54)) resumeRun();
                else if (inside(x, y, 48, 434, 264, 46)) restartRun();
            case 'won', 'lost':
                if (inside(x, y, 48, 434, 264, 54)) restartRun();
            default:
        }
    }

    function startRun():Void {
        clearPointer();
        model.start();
        hxd.Timer.reset();
        renderPhase();
    }

    function pauseRun():Void {
        clearPointer();
        model.pause();
        hxd.Timer.reset();
        renderPhase();
    }

    function resumeRun():Void {
        clearPointer();
        model.resume();
        hxd.Timer.reset();
        renderPhase();
    }

    function restartRun():Void {
        clearPointer();
        model.restart(newSeed());
        hxd.Timer.reset();
        renderPhase();
    }

    override function update(dt:Float):Void {
        if (Math.isFinite(dt) && dt > 0) visualTime += Math.min(dt, 0.1);
        if (model.phase == 'playing' && pointerId == -1) {
            var direction = (hxd.Key.isDown(hxd.Key.RIGHT) || hxd.Key.isDown(hxd.Key.D) ? 1 : 0)
                - (hxd.Key.isDown(hxd.Key.LEFT) || hxd.Key.isDown(hxd.Key.A) ? 1 : 0);
            if (direction != 0) model.setShipTargetX(model.shipX + direction * 480 * Math.min(dt, 0.1));
        }
        model.update(dt);
        if (model.phase != phaseShown) {
            clearPointer();
            if (model.phase == 'won' || model.phase == 'lost') persistBest();
            renderPhase();
        }
        draw();
    }

    function label(parent:Object, text:String, x:Float, y:Float, scale:Float, color:Int):Text {
        var result = new Text(hxd.res.DefaultFont.get(), parent);
        result.text = text;
        result.textColor = color;
        result.setScale(scale);
        result.x = x;
        result.y = y;
        return result;
    }

    function centered(parent:Object, text:String, y:Float, scale:Float, color:Int):Text {
        var result = label(parent, text, 0, y, scale, color);
        result.x = (360 - result.textWidth * scale) / 2;
        return result;
    }

    function button(shapes:Graphics, parent:Object, text:String, x:Float, y:Float,
            width:Float, height:Float, primary:Bool):Void {
        shapes.lineStyle(1.2, primary ? CYAN : 0x345268, primary ? 0.9 : 1);
        shapes.beginFill(primary ? 0x113d4d : 0x112132);
        shapes.drawRoundedRect(x, y, width, height, 8);
        shapes.endFill();
        shapes.lineStyle();
        centered(parent, text, y + (height - 18) / 2, 1, primary ? WHITE : MUTED);
        if (primary) {
            shapes.beginFill(CYAN);
            shapes.drawRect(x + 1, y + 15, 3, height - 30);
            shapes.endFill();
        }
    }

    function renderPhase():Void {
        phaseShown = model.phase;
        Sys.println('Neon Drift: phase=' + model.phase + ' score=' + model.score
            + ' best=' + model.bestScore + ' remaining=' + Std.int(Math.ceil(model.remaining)));
        panel.removeChildren();
        hud.visible = model.phase != 'title';
        var shapes = new Graphics(panel);
        if (model.phase == 'title') {
            label(panel, 'N / D', 26, 29, 0.8, CYAN);
            label(panel, 'SECTOR 01', 250, 30, 0.65, MUTED);
            centered(panel, 'NEON', 75, 6.2, WHITE);
            centered(panel, 'DRIFT', 139, 6.2, CYAN);
            centered(panel, 'A 45 SECOND SURVIVAL RUN', 239, 0.69, MUTED);
            centered(panel, 'DRAG TO STEER', 356, 0.95, WHITE);
            shapes.beginFill(PINK);
            shapes.drawRoundedRect(67, 392, 10, 10, 2);
            shapes.endFill();
            label(panel, 'AVOID', 86, 389, 0.75, MUTED);
            shapes.beginFill(LIME);
            shapes.drawCircle(195, 397, 5, 12);
            shapes.endFill();
            label(panel, 'COLLECT', 208, 389, 0.75, MUTED);
            button(shapes, panel, 'START RUN  >', 40, 450, 280, 54, true);
            centered(panel, '3 HITS. ONE SHOT AT THE SECTOR.', 528, 0.63, MUTED);
            centered(panel, 'PERSONAL BEST  ' + model.bestScore, 582, 0.8, LIME);
            if (saveFailed) centered(panel, 'BEST SCORE STORAGE UNAVAILABLE', 611, 0.6, PINK);
            return;
        }
        if (model.phase == 'playing') return;
        shapes.beginFill(0x07101e, 0.86);
        shapes.drawRect(0, 122, 360, 475);
        shapes.endFill();
        shapes.lineStyle(1, 0x2c5165);
        shapes.beginFill(0x0c1a2b, 0.98);
        shapes.drawRoundedRect(28, 162, 304, 367, 12);
        shapes.endFill();
        shapes.lineStyle();
        shapes.beginFill(model.phase == 'lost' ? PINK : CYAN);
        shapes.drawRect(48, 162, 264, 2);
        shapes.endFill();
        if (model.phase == 'paused') {
            centered(panel, 'RUN PAUSED', 204, 2.5, WHITE);
            centered(panel, 'TAKE A BREATH. KEEP YOUR LINE.', 265, 0.63, MUTED);
            centered(panel, Std.int(Math.ceil(model.remaining)) + ' SECONDS REMAIN', 304, 0.95, CYAN);
            button(shapes, panel, 'RESUME  >', 48, 368, 264, 54, true);
            button(shapes, panel, 'RESTART RUN', 48, 434, 264, 46, false);
        } else {
            var won = model.phase == 'won';
            centered(panel, won ? 'SECTOR CLEAR' : 'SHIP LOST', 191, 2.5, won ? CYAN : PINK);
            centered(panel, won ? 'YOU MADE IT THROUGH THE DRIFT' : 'THE DRIFT CLAIMED THIS RUN', 244, 0.62, MUTED);
            centered(panel, Std.string(model.score), 270, 4, WHITE);
            centered(panel, 'FINAL SCORE', 337, 0.65, MUTED);
            centered(panel, 'PERSONAL BEST  ' + model.bestScore, 367, 0.83, LIME);
            button(shapes, panel, 'DRIFT AGAIN  >', 48, 434, 264, 54, true);
            if (saveFailed) centered(panel, 'BEST SCORE COULD NOT BE SAVED', 504, 0.6, PINK);
        }
    }

    function draw():Void {
        drawBackground();
        world.clear();
        if (model.phase == 'title') {
            drawShip(world, 180, 297 + Math.sin(visualTime * 2) * 4, 1.65, true);
            world.lineStyle(1, CYAN, 0.25);
            world.drawCircle(180, 292, 54, 48);
            world.lineStyle();
        } else {
            for (entity in model.entities) {
                if (entity.kind == 'energy') drawEnergy(world, entity.x, entity.y, entity.radius);
                else drawObstacle(world, entity.x, entity.y, entity.radius, entity.id);
            }
            var visible = model.invulnerable <= 0 || Std.int(model.invulnerable * 12) % 2 == 0;
            drawShip(world, model.shipX, GameModel.SHIP_Y, 1, visible);
            drawHud();
        }
    }

    function drawBackground():Void {
        background.clear();
        background.beginFill(0x07101e);
        background.drawRect(0, 0, 360, 640);
        background.endFill();
        background.beginFill(0x0b182a, 0.7);
        background.drawRect(98, 0, 164, 640);
        background.endFill();
        var drift = model.phase == 'title' ? visualTime * 24 : model.elapsed * 42;
        for (i in 0...55) {
            var x = (i * 97 + 17) % 352 + 4;
            var y = ((i * 137 + 43) + drift * (0.25 + (i % 3) * 0.22)) % 640;
            background.beginFill(i % 5 == 0 ? CYAN : MUTED, i % 5 == 0 ? 0.42 : 0.2);
            background.drawRect(x, y, 1, i % 5 == 0 ? 5 : 2);
            background.endFill();
        }
        background.lineStyle(1, 0x28465d, 0.32);
        for (i in 0...7) {
            var x = i * 60;
            background.moveTo(180 + (x - 180) * 0.22, 132);
            background.lineTo(x, 640);
        }
        for (i in 0...11) {
            var y = 145 + ((i * 49 + drift) % 495);
            background.moveTo(0, y);
            background.lineTo(360, y);
        }
        background.lineStyle(1, CYAN, 0.13);
        background.moveTo(18, 0); background.lineTo(18, 640);
        background.moveTo(342, 0); background.lineTo(342, 640);
        background.lineStyle();
    }

    function drawHud():Void {
        hudShapes.clear();
        hudShapes.beginFill(0x07101e, 0.97);
        hudShapes.drawRect(0, 0, 360, 119);
        hudShapes.endFill();
        hudShapes.lineStyle(1, 0x254258);
        hudShapes.beginFill(0x0c1b2c);
        hudShapes.drawRoundedRect(18, 18, 324, 89, 9);
        hudShapes.endFill();
        hudShapes.lineStyle();
        hudShapes.beginFill(0x193146);
        hudShapes.drawRoundedRect(292, 21, 44, 44, 7);
        hudShapes.endFill();
        hudShapes.beginFill(CYAN);
        hudShapes.drawRect(307, 34, 4, 17);
        hudShapes.drawRect(317, 34, 4, 17);
        hudShapes.endFill();
        for (i in 0...3) {
            var x = 36 + i * 24;
            hudShapes.lineStyle(1, i < model.health ? PINK : 0x345065);
            hudShapes.beginFill(i < model.health ? PINK : 0x112233, i < model.health ? 0.9 : 0.5);
            diamond(hudShapes, x, 87, 6, 7);
            hudShapes.endFill();
        }
        hudShapes.lineStyle();
        hudShapes.beginFill(0x173347);
        hudShapes.drawRect(18, 116, 324, 2);
        hudShapes.endFill();
        hudShapes.beginFill(CYAN);
        hudShapes.drawRect(18, 116, 324 * model.remaining / 45, 2);
        hudShapes.endFill();
        hudShapes.beginFill(0x07101e, 0.88);
        hudShapes.drawRect(0, 593, 360, 47);
        hudShapes.endFill();
        var score = Std.string(model.score);
        while (score.length < 4) score = '0' + score;
        scoreText.text = score;
        timeText.text = Std.string(Std.int(Math.ceil(model.remaining)));
        timeText.textColor = model.remaining <= 10 ? PINK : CYAN;
        hintText.text = model.phase == 'playing' ? 'DRAG LEFT / RIGHT' : 'NEON DRIFT / SECTOR 01';
        hintText.x = (360 - hintText.textWidth * hintText.scaleX) / 2;
        saveWarning.text = saveFailed ? 'BEST SCORE STORAGE UNAVAILABLE' : '';
        saveWarning.x = (360 - saveWarning.textWidth * saveWarning.scaleX) / 2;
    }

    static function diamond(shapes:Graphics, x:Float, y:Float, rx:Float, ry:Float):Void {
        shapes.moveTo(x, y - ry);
        shapes.lineTo(x + rx, y);
        shapes.lineTo(x, y + ry);
        shapes.lineTo(x - rx, y);
        shapes.lineTo(x, y - ry);
    }

    function drawEnergy(shapes:Graphics, x:Float, y:Float, radius:Float):Void {
        shapes.beginFill(LIME, 0.08);
        shapes.drawCircle(x, y, radius + 7, 16);
        shapes.endFill();
        shapes.lineStyle(1.5, LIME, 0.8);
        shapes.drawCircle(x, y, radius, 16);
        shapes.lineStyle();
        shapes.beginFill(LIME);
        diamond(shapes, x, y, 4, 7);
        shapes.endFill();
    }

    function drawObstacle(shapes:Graphics, x:Float, y:Float, radius:Float, id:Int):Void {
        shapes.beginFill(PINK, 0.07);
        shapes.drawCircle(x, y, radius + 5, 12);
        shapes.endFill();
        shapes.lineStyle(1.5, PINK);
        shapes.beginFill(0x35172d, 0.95);
        var sides = 6;
        for (i in 0...7) {
            var angle = (i % sides) * Math.PI / 3 + id * 0.61;
            var px = x + Math.cos(angle) * radius;
            var py = y + Math.sin(angle) * radius;
            if (i == 0) shapes.moveTo(px, py); else shapes.lineTo(px, py);
        }
        shapes.endFill();
        shapes.lineStyle(1, PINK, 0.6);
        shapes.moveTo(x - radius * 0.3, y - radius * 0.3);
        shapes.lineTo(x + radius * 0.3, y + radius * 0.3);
        shapes.moveTo(x + radius * 0.3, y - radius * 0.3);
        shapes.lineTo(x - radius * 0.3, y + radius * 0.3);
        shapes.lineStyle();
    }

    function drawShip(shapes:Graphics, x:Float, y:Float, scale:Float, visible:Bool):Void {
        shapes.beginFill(CYAN, visible ? 0.06 : 0.025);
        shapes.drawCircle(x, y, 28 * scale, 24);
        shapes.endFill();
        shapes.beginFill(CYAN, 0.13);
        shapes.moveTo(x - 5 * scale, y + 10 * scale);
        shapes.lineTo(x, y + (35 + Math.sin(visualTime * 20) * 4) * scale);
        shapes.lineTo(x + 5 * scale, y + 10 * scale);
        shapes.lineTo(x - 5 * scale, y + 10 * scale);
        shapes.endFill();
        if (!visible) return;
        shapes.lineStyle(1.4, CYAN);
        shapes.beginFill(0x16475c);
        shapes.moveTo(x, y - 18 * scale);
        shapes.lineTo(x + 15 * scale, y + 12 * scale);
        shapes.lineTo(x, y + 6 * scale);
        shapes.lineTo(x - 15 * scale, y + 12 * scale);
        shapes.lineTo(x, y - 18 * scale);
        shapes.endFill();
        shapes.lineStyle();
        shapes.beginFill(WHITE);
        diamond(shapes, x, y - 2 * scale, 3 * scale, 7 * scale);
        shapes.endFill();
    }

    static function main():Void { new Main(); }
}
