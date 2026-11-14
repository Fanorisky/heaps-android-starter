package demo;

import h2d.Object;
import h2d.Text;
import demo.TouchControls.TouchAction;
import heapsandroid.Audio;

/** Touch controls above the playable GameBase sample; SDK checks are secondary. */
class FeaturesOverlay extends Object {
    final scene:h2d.Scene;
    final controls:Object;
    final featuresRoot:Object;
    final features:FeaturesView;
    final featureInput:h2d.Interactive;
    final featureBackdrop:h2d.Graphics;
    final featureBlocker:h2d.Interactive;
    final pauseLabel:Text;
    var open = false;

    public function new(scene:h2d.Scene) {
        super(scene);
        this.scene = scene;
        controls = new Object(this);
        button('FEATURES', 526, 12, 98, 30, showFeatures);
        pauseLabel = button('PAUSE', 16, 12, 102, 30, function() {
            App.ME.setGamePause(!App.ME.gameSession.paused);
            if (App.ME.gameSession.paused) Audio.pause(); else Audio.resume();
        });
        button('RESTART', 126, 12, 90, 30, function() {
            App.ME.touchControls.clear();
            App.ME.startGame();
        });
        holdButton('LEFT', 18, 278, 72, 64, Left);
        holdButton('RIGHT', 106, 278, 72, 64, Right);
        holdButton('JUMP', 530, 278, 92, 64, Jump);
        featureBackdrop = new h2d.Graphics(this);
        featureBlocker = new h2d.Interactive(scene.width, scene.height, this);
        featureBlocker.cancelEvents = true;
        featuresRoot = new Object(this);
        features = new FeaturesView(featuresRoot, new DemoSettings(), hideFeatures);
        featureInput = new h2d.Interactive(360, 640, featuresRoot);
        featureInput.cancelEvents = true;
        featureInput.onPush = function(event) features.click(event.relX, event.relY);
        setFeaturesVisible(false);
        hxd.Window.getInstance().addEventTarget(onWindowEvent);
        update();
    }

    function onWindowEvent(event:hxd.Event):Void {
        features.onWindowEvent(event);
        switch (event.kind) {
            case ERelease, EReleaseOutside: App.ME.touchControls.release(event.touchId);
            case EFocusLost: App.ME.touchControls.clear();
            default:
        }
    }

    function setFeaturesVisible(value:Bool):Void {
        featuresRoot.visible = featureBackdrop.visible = featureBlocker.visible = value;
        controls.visible = !value;
    }

    function showFeatures():Void {
        open = true;
        App.ME.setFeaturesOpen(true);
        setFeaturesVisible(true);
        features.showView();
    }

    function hideFeatures():Void {
        open = false;
        setFeaturesVisible(false);
        App.ME.setFeaturesOpen(false);
    }

    function makeButton(value:String, x:Float, y:Float, width:Float, height:Float):h2d.Interactive {
        var input = new h2d.Interactive(width, height, controls);
        input.x = x;
        input.y = y;
        input.backgroundColor = 0xcc19384c;
        input.cancelEvents = true;
        var text = new Text(hxd.res.DefaultFont.get(), input);
        text.text = value;
        text.textColor = 0xe4f4ff;
        text.setScale(0.75);
        text.x = (width - text.textWidth * text.scaleX) / 2;
        text.y = (height - text.textHeight * text.scaleY) / 2;
        return input;
    }

    function button(value:String, x:Float, y:Float, width:Float, height:Float, action:Void->Void):Text {
        var input = makeButton(value, x, y, width, height);
        input.onPush = function(_) action();
        return cast input.getChildAt(0);
    }

    function holdButton(value:String, x:Float, y:Float, width:Float, height:Float, action:TouchAction):Void {
        var input = makeButton(value, x, y, width, height);
        input.onPush = function(event) {
            if (!App.ME.gameSession.paused) App.ME.touchControls.press(event.touchId, action);
        };
        input.onRelease = input.onReleaseOutside = function(event) App.ME.touchControls.release(event.touchId);
    }

    public function update():Void {
        var scale = Math.min(scene.width / 640, scene.height / 360);
        controls.setScale(scale);
        controls.x = (scene.width - 640 * scale) / 2;
        controls.y = (scene.height - 360 * scale) / 2;
        var featureScale = Math.min(scene.width / 360, scene.height / 640);
        featuresRoot.setScale(featureScale);
        featuresRoot.x = (scene.width - 360 * featureScale) / 2;
        featuresRoot.y = (scene.height - 640 * featureScale) / 2;
        if (open) {
            featureBlocker.width = scene.width;
            featureBlocker.height = scene.height;
            featureBackdrop.clear();
            featureBackdrop.beginFill(0x07101e);
            featureBackdrop.drawRect(0, 0, scene.width, scene.height);
            featureBackdrop.endFill();
        }
        pauseLabel.text = App.ME.gameSession.paused ? 'RESUME' : 'PAUSE';
        pauseLabel.x = (102 - pauseLabel.textWidth * pauseLabel.scaleX) / 2;
        features.update();
    }

    public function shutdown():Void {
        hxd.Window.getInstance().removeEventTarget(onWindowEvent);
        App.ME.touchControls.clear();
        features.shutdown();
        remove();
    }
}
