package demo;

import h2d.Object;
import h2d.Text;
import heapsandroid.Audio;

/** SDK proof UI lives above GameBase and never owns the game scene's scaling. */
class FeaturesOverlay extends Object {
    final scene:h2d.Scene;
    final starter:Object;
    final features:FeaturesView;
    final featureInput:h2d.Interactive;
    final pauseLabel:Text;

    public function new(scene:h2d.Scene) {
        super(scene);
        this.scene = scene;
        starter = new Object(this);
        label('GAMEBASE', 170, 1.8);
        label('Empty game foundation', 222, 0.85);
        button('ANDROID FEATURES', 542, function() {
            App.ME.setFeaturesOpen(true);
            starter.visible = false;
            features.showView();
            featureInput.visible = true;
        });
        pauseLabel = button('PAUSE', 588, function() {
            App.ME.setGamePause(!App.ME.gameSession.paused);
            if (App.ME.gameSession.paused) Audio.pause();
        });
        features = new FeaturesView(this, new DemoSettings(), function() {
            featureInput.visible = false;
            starter.visible = true;
            App.ME.setFeaturesOpen(false);
        });
        featureInput = new h2d.Interactive(360, 640, this);
        featureInput.onPush = function(event) features.click(event.relX, event.relY);
        featureInput.visible = false;
        hxd.Window.getInstance().addEventTarget(features.onWindowEvent);
        update();
    }

    function label(value:String, y:Float, scale:Float):Text {
        var text = new Text(hxd.res.DefaultFont.get(), starter);
        text.text = value;
        text.textColor = 0xe4f4ff;
        text.setScale(scale);
        text.x = (360 - text.textWidth * scale) / 2;
        text.y = y;
        return text;
    }

    function button(value:String, y:Float, action:Void->Void):Text {
        var input = new h2d.Interactive(280, 34, starter);
        input.x = 40;
        input.y = y;
        input.backgroundColor = 0xff19384c;
        input.onPush = function(_) action();
        return label(value, y + 9, 0.7);
    }

    public function update():Void {
        var scale = Math.min(scene.width / 360, scene.height / 640);
        setScale(scale);
        x = (scene.width - 360 * scale) / 2;
        y = (scene.height - 640 * scale) / 2;
        pauseLabel.text = App.ME.gameSession.paused ? 'RESUME GAME' : 'PAUSE GAME';
        pauseLabel.x = (360 - pauseLabel.textWidth * pauseLabel.scaleX) / 2;
        features.update();
    }

    public function shutdown():Void {
        hxd.Window.getInstance().removeEventTarget(features.onWindowEvent);
        features.shutdown();
        remove();
    }
}
