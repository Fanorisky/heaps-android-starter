import demo.TouchControls;
import demo.TouchControls.TouchAction;

class TouchControlsTest {
    static function check(value:Bool, message:String) { if (!value) throw message; }
    static function main() {
        var input = new TouchControls();
        check(input.move == 0 && !input.takeJump(), 'Fresh controls idle');
        input.press(11, Left);
        check(input.move == -1, 'Left is held');
        input.press(12, Jump);
        check(input.move == -1 && input.takeJump(), 'Independent finger can jump while moving');
        check(!input.takeJump(), 'Held jump fires once');
        input.release(12);
        check(input.move == -1, 'Releasing jump does not release left');
        input.press(13, Right);
        check(input.move == 0, 'Opposing directions cancel');
        input.release(11);
        check(input.move == 1, 'Releasing left preserves right');
        input.release(999);
        check(input.move == 1, 'Unknown release is harmless');
        input.press(14, Right);
        input.release(13);
        check(input.move == 1, 'Another finger can keep direction held');
        input.press(15, Jump);
        input.clear();
        check(input.move == 0 && !input.takeJump(), 'Pause/background discards held buttons and queued jump');
        input.press(15, Jump);
        check(input.takeJump(), 'New jump works after resume');
        Sys.println('GAMEBASE_TOUCH_TEST_PASS');
    }
}
