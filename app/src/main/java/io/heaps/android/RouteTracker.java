package io.heaps.android;
import java.util.Arrays;
/** Compare output IDs as a set; callback batches may reorder or repeat devices. */
final class RouteTracker {
    private int[] outputs;
    RouteTracker(int[] outputs) { this.outputs = normalize(outputs); }
    boolean changed(int[] next) {
        next = normalize(next);
        if (Arrays.equals(outputs, next)) return false;
        outputs = next;
        return true;
    }
    private static int[] normalize(int[] ids) { return Arrays.stream(ids).sorted().distinct().toArray(); }
}
