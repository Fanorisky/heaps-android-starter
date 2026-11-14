import heapsandroid.Android;
import heapsandroid.Audio;
import heapsandroid.Audio.AudioState;
import heapsandroid.Display;
import heapsandroid.Keyboard;
import heapsandroid.Lifecycle;
import heapsandroid.Sensors;
import heapsandroid.Sensors.SensorKind;
import heapsandroid.internal.Native;
import hxd.res.Sound;
import hxd.snd.Channel;

/** Real channels and public platform state. External runner performs framework
 * HOME/foreground cycles; no injected production native failure controls. */
class ReliabilityRegression {
 public static var isRunning(default,null)=false;
 static var report:(Bool,String)->Void;
 static var sound:Sound;
 static var audible:Channel;
 static var muted:Channel;
 static var userPaused:Channel;
 static var phase=0;
 static var positions:Array<Float>;
 static var deadline:Float;
 static var resumeTimeout:Float;
 static var cycles=0;
 static var background=false;
 static var unsubscribe:Void->Void;
 static var savedImmersive:Bool;
 static var savedAwake:Bool;
 static function check(ok:Bool,text:String):Void {if(!ok)throw text;}
 public static function start(sample:Sound,callback:(Bool,String)->Void):Void {
  if(isRunning){callback(false,'Already running');return;}
  report=callback;sound=sample;isRunning=true;phase=0;cycles=0;background=false;
  savedImmersive=Display.immersive;savedAwake=Display.keepAwake;
  try {
   audible=sample.play(true);muted=sample.play(true,0);muted.mute=true;
   userPaused=sample.play(true);userPaused.pause=true;
   check(Audio.state==Running,'Raw startup audio failed');
   unsubscribe=Lifecycle.subscribe(event->{
    if(!isRunning||phase<4)return;
    if(event==Background){background=true;deadline=haxe.Timer.stamp()+.08;phase=5;}
    if(event==Foreground&&background){phase=6;deadline=haxe.Timer.stamp()+.12;}
   });
   deadline=haxe.Timer.stamp()+.3;
  }catch(error:Dynamic){finish(false,Std.string(error));}
 }
 static function snapshot():Void {positions=[audible.position,muted.position,userPaused.position];}
 static function frozen():Void {
  var channels=[audible,muted,userPaused];
  for(i in 0...channels.length)check(!channels[i].isReleased()&&channels[i].pause&&Math.abs(channels[i].position-positions[i])<.01,'Channel changed during lifecycle pause');
 }
 public static function update():Void {
  if(!isRunning)return;
  try {
   Android.update();Audio.poll();var now=haxe.Timer.stamp();if(now<deadline)return;
   switch(phase){
    case 0:
     check(audible.position>0&&(@:privateAccess muted.isVirtual),'Raw audible/virtual progress missing');
     Android.shutdown();check(audible.pause&&muted.pause&&Audio.state==Paused,'SDK stop failed');
     phase=1;deadline=now+.08;
    case 1:snapshot();phase=2;deadline=now+.35;
    case 2:
     frozen();Android.init();check(Lifecycle.foreground&&Audio.state==Paused,'SDK reinitialization snapshot/intent failed');
     check(Audio.resume()&&!audible.pause&&userPaused.pause,'SDK explicit resume failed');
     phase=3;deadline=now+.15;resumeTimeout=now+1;
    case 3:
     if(audible.position==positions[0]){if(now<resumeTimeout){deadline=now+.03;return;}throw 'Resume progress missing within 1s';}
     Display.setKeepAwake(false);Display.setImmersive(true);
     phase=4;deadline=now+.2;
    case 4:
     check(Display.immersive&&!Display.keepAwake,'Applied display state incorrect');
     snapshot();phase=7;Sys.println('RELIABILITY_READY cycle='+cycles);
    case 5:
     check(Audio.state!=Running,'Audio running in background');
     check(!Keyboard.active,'IME active in background');
     check(Sensors.sample(Accelerometer)==null&&Sensors.sample(Gyroscope)==null,'Sensor sample active in background');
     phase=7;
    case 6:
     check(Audio.state==Paused&&audible.pause&&muted.pause,'Foreground restored playback intent');
     // A paused source may synchronize one device offset after focus loss;
     // muted virtual time must never consume the background interval.
     check(Math.abs(muted.position-positions[1])<.02,'Muted loop skipped background wall time');
     check(userPaused.pause,'User pause erased by lifecycle');
     cycles++;background=false;
     check(Audio.resume(),'Explicit resume after foreground denied');
     if(cycles>=10){
      var prior=audible;check(Audio.recover(),'Real recovery failed');
      check(prior.isReleased()&&muted.isReleased()&&userPaused.isReleased(),'Recovery retained old handles');
      check(Audio.state==Paused,'Recovery armed playback');
      var next=sound.play(true);check(next!=null&&!next.pause&&Audio.state==Running,'Explicit raw replay failed');next.stop();
      finish(true,'10 framework cycles, SDK restart, raw/virtual/user pause and fresh paused recovery');
     }else{phase=4;deadline=now+.15;}
    case 7:
     // Keep the last actual foreground frame, not the earlier READY log time.
     // Background/Foreground can arrive together; never overwrite after loss.
     if(!background&&Lifecycle.foreground&&Audio.state==Running)snapshot();
   }
  }catch(error:Dynamic){finish(false,Std.string(error));}
 }
 static function finish(ok:Bool,message:String):Void {
  isRunning=false;if(unsubscribe!=null)unsubscribe();unsubscribe=null;
  for(channel in [audible,muted,userPaused])if(channel!=null&&!channel.isReleased())channel.stop();
  Display.setImmersive(savedImmersive);Display.setKeepAwake(savedAwake);
  var callback=report;report=null;sound=null;audible=muted=userPaused=null;
  if(callback!=null)callback(ok,message);
 }
}
