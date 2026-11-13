package heapsandroid.internal;

/** Root provider kept separate from path resolution, usable by other system hosts. */
class StorageRoots {
    public final files:String;
    public final cache:String;
    public function new(files:String,cache:String) {
        this.files=files; this.cache=cache;
    }
}
