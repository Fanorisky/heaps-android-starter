package heapsandroid;
import heapsandroid.internal.LifecycleStore;
enum abstract LifecycleEvent(Int) from Int to Int {
 var Foreground = 0;
 var Background = 1;
 var FocusGained = 2;
 var FocusLost = 3;
}
/** Events are dispatched exclusively by Android.update on the Heaps thread. */
class Lifecycle {
 static var store = new LifecycleStore();
 public static var foreground(get, never):Bool;
 public static var focused(get, never):Bool;
 static inline function get_foreground() return store.foreground;
 static inline function get_focused() return store.focused;
 public static function subscribe(callback:LifecycleEvent->Void):Void->Void return store.subscribe(callback);
 @:allow(heapsandroid.Android) static function ingest(event:Int) store.ingest(event);
 @:allow(heapsandroid.Android) static function reconcile(snapshot:Int) store.reconcile(snapshot);
 @:allow(heapsandroid.Android) static function dispatch() store.dispatch();
 @:allow(heapsandroid.Android) static function reset() store.reset();
}
