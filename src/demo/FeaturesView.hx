package demo;

import h2d.Graphics;
import h2d.Object;
import h2d.Text;
import hxd.Event;
import heapsandroid.Audio;
import heapsandroid.Keyboard;
import heapsandroid.Haptics;
import heapsandroid.Sensors;
import heapsandroid.Sensors.SensorKind;
import heapsandroid.Display;
import heapsandroid.Device;
import heapsandroid.Lifecycle;
import heapsandroid.Lifecycle.LifecycleEvent;
import AudioRegression;
import ReliabilityRegression;
import PreferencesRegression;
import heapsandroid.Audio.AudioState;

typedef FeatureButton={x:Float,y:Float,w:Float,h:Float,action:Void->Void};

/** Live developer proof of the reusable SDK, independent of GameBase gameplay. */
class FeaturesView extends Object {
    final settings:DemoSettings;
    final editor:UnicodeEditor;
    final close:Void->Void;
    var buttons:Array<FeatureButton>=[];
    var audioText:Text;
    var musicText:Text;
    var sfxText:Text;
    var editorText:Text;
    var hapticsText:Text;
    var accelText:Text;
    var gyroText:Text;
    var displayText:Text;
    var statusText:Text;
    var accel=false;
    var gyro=false;
    var unsubscribe:Void->Void;
    static inline var CYAN=0x65edff;
    static inline var WHITE=0xe4f4ff;
    public function new(parent:Object,settings:DemoSettings,close:Void->Void) {
        super(parent); this.settings=settings; this.close=close;
        editor=new UnicodeEditor(64); editor.setText(settings.editorText);
        var g=new Graphics(this); g.beginFill(0x07101e); g.drawRect(0,0,360,640); g.endFill();
        label('ANDROID FEATURES',18,17,1.15,CYAN);
        var device=Device.info();
        label('SDK '+device.sdk+' / APP '+device.appAbi,18,48,0.72);
        label('SUPPORTED '+device.supportedAbis.join(', '),18,64,0.6);
        label(device.model,18,79,0.65);
        audioText=label('',18,99,0.72);
        button('MUSIC',18,116,60,28,function(){Audio.playMusic(hxd.Res.android.music,true);status('Looping music requested');});
        button('PAUSE',84,116,60,28,function(){Audio.pause();status('Audio paused');});
        button('RESUME',150,116,60,28,function(){status(Audio.resume()?'Audio resumed':'Audio unavailable / focus denied');});
        button('STOP',216,116,54,28,function(){Audio.stopMusic();status('Music stopped');});
        button('CHECKS',276,116,66,28,function(){
            status('Audio checks running');
            AudioRegression.start(hxd.Res.android.music,function(ok,message){
                Sys.println((ok ? 'AUDIO_TEST_PASS ' : 'AUDIO_TEST_FAIL ') + message);
                status((ok ? 'Audio checks passed: ' : 'Audio checks failed: ') + message);
                statusText.textColor = ok ? WHITE : 0xff587f;
            });
        });
        musicText=label('',18,151,0.7);
        button('-',160,148,36,27,function(){settings.musicVolume-=0.1;applySettings();});
        button('+',202,148,36,27,function(){settings.musicVolume+=0.1;applySettings();});
        button('MUTE',244,148,98,27,function(){settings.musicMuted=!settings.musicMuted;applySettings();});
        sfxText=label('',18,185,0.7);
        button('-',160,182,36,27,function(){settings.sfxVolume-=0.1;applySettings();});
        button('+',202,182,36,27,function(){settings.sfxVolume+=0.1;applySettings();});
        button('MUTE',244,182,98,27,function(){settings.sfxMuted=!settings.sfxMuted;applySettings();});
        button('UI',18,218,50,28,function(){testSound(hxd.Res.android.ui);});
        button('START',73,218,50,28,function(){testSound(hxd.Res.android.start);});
        button('PICK',128,218,50,28,function(){testSound(hxd.Res.android.pickup);});
        button('HIT',183,218,50,28,function(){testSound(hxd.Res.android.hit);});
        button('WIN',238,218,50,28,function(){testSound(hxd.Res.android.win);});
        button('LOSE',293,218,49,28,function(){testSound(hxd.Res.android.lose);});
        label('COMMITTED TEXT / 64 UNICODE SCALARS',18,259,0.64,CYAN);
        editorText=label('',18,278,0.83);editorText.maxWidth=320;
        button('SHOW KEYBOARD',18,308,155,29,function(){if(Keyboard.show({x:18,y:278,width:324,height:26}))editor.begin();else status('Keyboard unavailable');});
        button('HIDE KEYBOARD',187,308,155,29,function(){cancelEditor();});
        hapticsText=label('',18,346,0.66);
        button('TOGGLE',18,364,100,28,function(){settings.haptics=!settings.haptics;applySettings();});
        button('VIBRATE',130,364,100,28,function(){status(Haptics.vibrate(120)?'Vibration requested':'Haptics unavailable / disabled');});
        button('CANCEL',242,364,100,28,function(){Haptics.cancel();status('Vibration cancelled');});
        button('ACCEL ON/OFF',18,402,155,28,function(){if(accel){Sensors.disable(Accelerometer);accel=false;}else accel=Sensors.enable(Accelerometer);status(accel?'Accelerometer enabled':'Accelerometer disabled / unavailable');});
        button('GYRO ON/OFF',187,402,155,28,function(){if(gyro){Sensors.disable(Gyroscope);gyro=false;}else gyro=Sensors.enable(Gyroscope);status(gyro?'Gyroscope enabled':'Gyroscope disabled / unavailable');});
        accelText=label('',18,437,0.58); gyroText=label('',18,457,0.58);
        button('IMMERSIVE',18,484,155,29,function(){Display.setImmersive(!Display.immersive);});
        button('KEEP AWAKE',187,484,155,29,function(){Display.setKeepAwake(!Display.keepAwake);});
        displayText=label('',18,522,0.64);
        statusText=label('Tap a control to test the Android host.',18,553,0.66);statusText.maxWidth=324;
        button('BACK TO GAMEBASE',40,595,280,32,function(){hideView();close();});
        button('STRESS',276,574,66,18,function(){
            status('Lifecycle stress running');
            ReliabilityRegression.start(hxd.Res.android.music,function(ok,message){
                Sys.println((ok?'RELIABILITY_TEST_PASS ':'RELIABILITY_TEST_FAIL ')+message);
                status(message);
            });
        });
        unsubscribe=Lifecycle.subscribe(function(event){if(event==Background){cancelEditor();settings.commit();}});
        visible=false;
        if(PreferencesRegression.run()) applySettings();
        else status('Preferences self-check failed; startup defaults were not saved');
        refresh();
    }
    function label(value:String,x:Float,y:Float,scale:Float,color:Int=WHITE):Text {
        var t=new Text(hxd.res.DefaultFont.get(),this); t.text=value;t.x=x;t.y=y;t.setScale(scale);t.textColor=color;return t;
    }
    function button(value:String,x:Float,y:Float,w:Float,h:Float,action:Void->Void):Void {
        var g=new Graphics(this);g.lineStyle(1,0x345268);g.beginFill(0x112132);g.drawRoundedRect(x,y,w,h,5);g.endFill();g.lineStyle();
        var t=label(value,0,y+8,0.65,CYAN);t.x=x+(w-t.textWidth*t.scaleX)/2;
        buttons.push({x:x,y:y,w:w,h:h,action:action});
    }
    function status(value:String):Void {statusText.text=value;statusText.textColor=WHITE;Sys.println('Heaps Android Features: '+value);}
    function testSound(sound:hxd.res.Sound):Void status(Audio.playSfx(sound)!=null?'SFX requested':'Audio unavailable / focus denied');
    public function applySettings():Void {
        Audio.musicVolume=settings.musicVolume;Audio.sfxVolume=settings.sfxVolume;
        Audio.musicMuted=settings.musicMuted;Audio.sfxMuted=settings.sfxMuted;Haptics.enabled=settings.haptics;
        if(!settings.commit()) {if(statusText!=null)status('Preferences could not be saved');}
    }
    public function showView():Void {visible=true;refresh();}
    public function hideView():Void {
        visible=false;cancelEditor(); Sensors.disable(Accelerometer);Sensors.disable(Gyroscope);accel=gyro=false;Haptics.cancel();settings.commit();
    }
    function cancelEditor():Void {Keyboard.hide();editor.cancel();settings.editorText=editor.text;settings.commit();}
    public function onWindowEvent(event:Event):Void {
        if(!visible)return;
        switch(event.kind) {
            case ETextInput: editor.appendCodePoint(event.charCode);settings.editorText=editor.text;settings.commit();
            case EKeyDown: if(event.keyCode==hxd.Key.BACKSPACE){editor.backspace();settings.editorText=editor.text;settings.commit();}
            case EFocusLost: cancelEditor();
            default:
        }
    }
    public function click(x:Float,y:Float):Void {
        for(b in buttons)if(x>=b.x && x<=b.x+b.w && y>=b.y && y<=b.y+b.h){b.action();refresh();return;}
    }
    public function update():Void {if(ReliabilityRegression.isRunning)ReliabilityRegression.update();if(AudioRegression.isRunning)AudioRegression.update();if(visible)refresh();}
    function sampleText(kind:SensorKind,name:String,enabled:Bool):String {
        if(!Sensors.available(kind))return name+' unavailable';
        var sample=Sensors.sample(kind);
        if(sample==null)return name+(enabled?' waiting for sample':' disabled');
        function n(v:Float):String return Std.string(Math.round(v*100)/100);
        return name+' '+n(sample.x)+' '+n(sample.y)+' '+n(sample.z)+' ns='+haxe.Int64.toStr(sample.timestampNs);
    }
    function refresh():Void {
        audioText.text='AUDIO '+(Audio.state==Running?'RUNNING':Audio.state==Paused?'PAUSED':'UNAVAILABLE');
        musicText.text='MUSIC '+Std.int(settings.musicVolume*100)+'%'+(settings.musicMuted?' MUTED':'');
        sfxText.text='SFX '+Std.int(settings.sfxVolume*100)+'%'+(settings.sfxMuted?' MUTED':'');
        editorText.text=editor.text+(editor.active?' _':'');
        hapticsText.text='HAPTICS '+(!Haptics.available?'UNAVAILABLE':settings.haptics?'ENABLED':'DISABLED');
        accelText.text=sampleText(Accelerometer,'ACC',accel);gyroText.text=sampleText(Gyroscope,'GYR',gyro);
        var i=Display.safeInsets;
        displayText.text='IMM '+Display.immersive+' / AWAKE '+Display.keepAwake+'\nINSETS '+i.left+','+i.top+','+i.right+','+i.bottom;
    }
    public function shutdown():Void {hideView();unsubscribe();}
}
