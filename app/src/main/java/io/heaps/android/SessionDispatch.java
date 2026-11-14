package io.heaps.android;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Consumer;
/** One mutex covers validation and native publication. Lock order: this -> resource -> native audio.
 * Never wait synchronously for the UI thread while holding this monitor. */
final class SessionDispatch {
    static final class Session {
        final long epoch;
        private Session(long epoch) { this.epoch = epoch; }
    }
    interface Publication {
        void start(long epoch, boolean foreground, boolean windowFocus);
        void stop(long epoch);
    }
    private static final AtomicLong epochs = new AtomicLong();
    private final NativeDispatch nativeDispatch;
    private final Publication publication;
    private Session current;
    private boolean destroyed, foreground, windowFocus;
    SessionDispatch(NativeDispatch nativeDispatch, Publication publication) {
        this.nativeDispatch = nativeDispatch; this.publication = publication;
    }
    synchronized Session start() {
        if (destroyed || !nativeDispatch.ready()) return null;
        if (current != null) return current;
        long epoch = epochs.updateAndGet(previous -> previous == Long.MAX_VALUE ? previous : previous + 1);
        if (epoch == Long.MAX_VALUE) return null;
        current = new Session(epoch);
        nativeDispatch.run(() -> publication.start(epoch, foreground, windowFocus));
        return current;
    }
    synchronized Session current() { return current; }
    synchronized boolean valid(Session session) { return session != null && current == session && !destroyed && nativeDispatch.ready(); }
    synchronized boolean foreground() { return foreground; }
    synchronized boolean windowFocus() { return windowFocus; }
    synchronized boolean run(Session session, Runnable callback) {
        if (!valid(session)) return false;
        return nativeDispatch.run(callback);
    }
    synchronized void foreground(boolean value, Consumer<Session> callback) {
        foreground = value;
        if (valid(current)) callback.accept(current);
    }
    synchronized void windowFocus(boolean value, Consumer<Session> callback) {
        windowFocus = value;
        if (valid(current)) callback.accept(current);
    }
    synchronized Session stop() {
        Session stopped = current;
        if (stopped == null) return null;
        nativeDispatch.run(() -> publication.stop(stopped.epoch));
        current = null;
        return stopped;
    }
    synchronized void destroy() { stop(); destroyed = true; }
}
