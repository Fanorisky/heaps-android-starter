package demo;

/** A bounded committed-text editor. SDL composition is owned by Keyboard. */
class UnicodeEditor {
    public var text(default,null):String='';
    public var active(default,null):Bool=false;
    final limit:Int;
    var scalars:Array<Int>=[];
    public function new(maxLength:Int=64) { limit=Std.int(Math.max(0,maxLength)); }
    public function begin():Void active=true;
    public function cancel():Void active=false;
    public function setText(value:String):Void {
        scalars=[];
        if(value!=null) for(code in new haxe.iterators.StringIteratorUnicode(value)) add(code);
        rebuild();
    }
    public function appendText(value:String):Void {
        if(!active || value==null) return;
        for(code in new haxe.iterators.StringIteratorUnicode(value)) add(code);
        rebuild();
    }
    public function appendCodePoint(code:Int):Void { if(active) { add(code); rebuild(); } }
    function add(code:Int):Void {
        if(scalars.length<limit && code>=0x20 && code<=0x10FFFF && !(code>=0xD800 && code<=0xDFFF)) scalars.push(code);
    }
    public function backspace():Void { if(active) { scalars.pop(); rebuild(); } }
    static function character(code:Int):String {
        #if hl
        return String.fromCharCode(code);
        #elseif utf16
        if(code>0xFFFF) { var n=code-0x10000; return String.fromCharCode(0xD800+(n>>10))+String.fromCharCode(0xDC00+(n&1023)); }
        #else
        return String.fromCharCode(code);
        #end
    }
    function rebuild():Void { var b=new StringBuf(); for(code in scalars) b.add(character(code)); text=b.toString(); }
}
