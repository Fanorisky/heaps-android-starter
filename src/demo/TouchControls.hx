package demo;

enum abstract TouchAction(Int) {
    var Left = 0;
    var Right = 1;
    var Jump = 2;
}

/** One owner per finger; releasing one touch cannot cancel another control. */
class TouchControls {
    final held = new Map<Int, TouchAction>();
    var jumpPending = false;
    public var move(get, never):Int;

    public function new() {}
    function get_move():Int {
        var left = false;
        var right = false;
        for (action in held) {
            if (action == Left) left = true;
            if (action == Right) right = true;
        }
        return (right ? 1 : 0) - (left ? 1 : 0);
    }
    public function press(finger:Int, action:TouchAction):Void {
        if (held.exists(finger) && held.get(finger) == action) return;
        held.set(finger, action);
        if (action == Jump) jumpPending = true;
    }
    public function release(finger:Int):Void held.remove(finger);
    public function takeJump():Bool {
        var pending = jumpPending;
        jumpPending = false;
        return pending;
    }
    public function clear():Void {
        held.clear();
        jumpPending = false;
    }
}
