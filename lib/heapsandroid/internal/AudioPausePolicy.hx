package heapsandroid.internal;

/** User pause survives effective gate pauses, including edits while gated. */
class AudioPausePolicy {
    var requested:Bool;
    public function new(paused:Bool) requested = paused;
    public function request(paused:Bool, running:Bool):Bool {
        requested = paused;
        return effective(running);
    }
    public inline function effective(running:Bool):Bool return !running || requested;
}
