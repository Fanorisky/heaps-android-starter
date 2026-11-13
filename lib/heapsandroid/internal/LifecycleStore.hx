package heapsandroid.internal;
import heapsandroid.Lifecycle.LifecycleEvent;
private typedef Listener = { var active:Bool; var callback:LifecycleEvent->Void; };
/** Bounded/coalescing queue; callbacks may unsubscribe during dispatch. */
class LifecycleStore {
 public var foreground(default,null) = false;
 public var focused(default,null) = false;
 var listeners:Array<Listener> = [];
 var events:Array<LifecycleEvent> = [];
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
  if(events.length == 32) events.shift();
  events.push(value);
  switch value {
   case Foreground: foreground = true;
   case Background: foreground = false;
   case FocusGained: focused = true;
   case FocusLost: focused = false;
  }
 }
 public function dispatch():Void {
  var pending = events; events = [];
  for(event in pending) for(listener in listeners.copy()) if(listener.active) listener.callback(event);
 }
}
