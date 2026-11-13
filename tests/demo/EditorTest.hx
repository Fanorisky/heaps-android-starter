import demo.UnicodeEditor;
class EditorTest {
    static var count=0;
    static function eq(a:Dynamic,b:Dynamic,n:String) { count++; if(a!=b) throw n+': expected '+b+', got '+a; }
    static function main() {
        var e=new UnicodeEditor(5);
        e.begin(); e.appendText('aé中😀'); eq(e.text,'aé中😀','paste full commit');
        e.backspace(); eq(e.text,'aé中','delete nonBMP scalar');
        e.appendCodePoint(0x1F680); eq(e.text,'aé中🚀','scalar event');
        e.appendText('xy'); eq(e.text,'aé中🚀x','scalar length bound');
        e.backspace(); e.backspace(); eq(e.text,'aé中','two scalars');
        e.cancel(); e.appendText('no'); e.backspace(); eq(e.text,'aé中','background cancels edits'); eq(e.active,false,'background inactive');
        e.begin(); e.appendCodePoint(0xD800); e.appendCodePoint(0x110000); eq(e.text,'aé中','invalid scalars ignored');
        e.setText('😀😀😀😀😀😀'); eq(e.text,'😀😀😀😀😀','persisted text bounded');
        Sys.println('Editor: '+count+' assertions passed');
    }
}
