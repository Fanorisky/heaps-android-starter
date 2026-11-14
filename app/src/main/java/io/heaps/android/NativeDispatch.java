package io.heaps.android;
import java.util.function.BooleanSupplier;
/** Shared production boundary: SDL's broken-library screen must never dispatch JNI. */
final class NativeDispatch {
    private final BooleanSupplier ready;
    NativeDispatch(BooleanSupplier ready) { this.ready = ready; }
    boolean ready() { return ready.getAsBoolean(); }
    boolean run(Runnable callback) {
        if (!ready()) return false;
        callback.run();
        return true;
    }
}
