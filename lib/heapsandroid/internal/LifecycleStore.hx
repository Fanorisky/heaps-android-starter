package heapsandroid.internal;
import heapsandroid.Lifecycle.LifecycleEvent;
private typedef Listener = { var active:Bool; var callback:LifecycleEvent->Void; };
/** Bounded/coalescing queue; callbacks may unsubscribe during dispatch. */
class LifecycleStore {
 public var foreground(default,null) = false;
 public var focused(default,null) = false;
 var listeners:Array<Listener> = [];
 var events:Array<LifecycleEvent> = [];
 var generation = 0;
 public function new() {}
 public function subscribe(callback:LifecycleEvent->Void):Void->Void {
  if(callback == null) throw "Lifecycle callback is null";
  var listener = {active:true, callback:callback}; listeners.push(listener);
  return function() { listener.active = false; listeners.remove(listener); };
 }
 public function ingest(event:Int):Void {
  if(event < 0 || event > 3) return;
  var value:LifecycleEvent = cast event;
  if(events.length > 0 && events[events.length-1] == value) return;
  if(events.length == 32) {
   var drop = 0;
   while(drop < events.length && ((events[drop]:Int) < 2) != (event < 2)) drop++;
   if(drop == events.length) drop = 0;
   events.splice(drop, 1);
  }
  events.push(value);
  switch value {
   case Foreground: foreground = true;
   case Background: foreground = false;
   case FocusGained: focused = true;
   case FocusLost: focused = false;
  }
 }
 /** Repair state if a bounded native queue dropped an older transition. */
 public function reconcile(snapshot:Int):Void {
  var nextForeground = (snapshot & 1) != 0;
  var nextFocused = (snapshot & 2) != 0;
  if(foreground != nextForeground) ingest(nextForeground ? 0 : 1);
  if(focused != nextFocused) ingest(nextFocused ? 2 : 3);
 }
 /** Reversible SDK stop preserves subscribers but discards queued session events. */
 public function reset():Void {
  generation++;
  events = [];
  reconcile(0);
  dispatch();
 }
 public function dispatch():Void {
  var dispatchGeneration = generation;
  var pending = events; events = [];
  for(event in pending) for(listener in listeners.copy()) {
   if(generation != dispatchGeneration) return;
   if(listener.active) listener.callback(event);
  }
 }
}
