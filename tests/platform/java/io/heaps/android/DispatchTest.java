package io.heaps.android;
import java.util.*;
import java.util.concurrent.*;
public final class DispatchTest {
    static void check(boolean condition, String message) { if (!condition) throw new AssertionError(message); }
    public static void main(String[] args) throws Exception {
        boolean[] ready = {false};
        int[] calls = {0};
        NativeDispatch nativeDispatch = new NativeDispatch(() -> ready[0]);
        check(!nativeDispatch.run(() -> calls[0]++), "broken library dispatched JNI");
        ready[0] = true;
        check(nativeDispatch.run(() -> calls[0]++), "loaded library rejected");
        check(calls[0] == 1, "broken library callback executed");
        List<String> events = Collections.synchronizedList(new ArrayList<>());
        SessionDispatch sessions = new SessionDispatch(nativeDispatch, new SessionDispatch.Publication() {
            public void start(long epoch, boolean fg, boolean focus) { events.add("start:"+epoch+":"+fg+":"+focus); }
            public void stop(long epoch) { events.add("stop:"+epoch); }
        });
        sessions.foreground(true, s -> {});
        sessions.windowFocus(false, s -> {});
        SessionDispatch.Session first = sessions.start();
        check(events.get(0).equals("start:"+first.epoch+":true:false"), "start lost live Activity snapshot");
        sessions.stop(); sessions.stop();
        sessions.windowFocus(true, s -> {});
        SessionDispatch.Session second = sessions.start();
        check(second != first && second.epoch > first.epoch, "SDK restart did not create unique identity");
        check(events.get(2).equals("start:"+second.epoch+":true:true"), "restart lost stopped Activity state");
        for(String callback : new String[]{"sensor", "display", "route", "focus", "cleanup"}) {
            check(!sessions.run(first, () -> events.add(callback)), "stale "+callback+" callback accepted");
        }
        check(sessions.run(second, () -> events.add("current")), "current callback rejected");
        CountDownLatch entered = new CountDownLatch(1), release = new CountDownLatch(1);
        Thread callback = new Thread(() -> sessions.run(second, () -> {
            entered.countDown();
            try { release.await(); } catch (InterruptedException e) { throw new RuntimeException(e); }
            events.add("callback-complete");
        }));
        callback.start(); check(entered.await(5, TimeUnit.SECONDS), "callback did not enter");
        Thread stopping = new Thread(sessions::stop); stopping.start();
        long deadline = System.nanoTime()+TimeUnit.SECONDS.toNanos(5);
        while (stopping.getState() != Thread.State.BLOCKED && stopping.isAlive() && System.nanoTime() < deadline) Thread.yield();
        check(stopping.getState() == Thread.State.BLOCKED, "stop did not wait for validated callback publication");
        release.countDown(); callback.join(5000); stopping.join(5000);
        check(!callback.isAlive() && !stopping.isAlive(), "dispatch deadlocked");
        check(events.indexOf("callback-complete") < events.indexOf("stop:"+second.epoch), "stop interleaved validation/publication");
        SessionDispatch.Session third = sessions.start();
        sessions.destroy();
        check(sessions.start() == null && !sessions.run(third, () -> events.add("destroyed")), "destroy was reversible");
        ready[0] = false; sessions.foreground(false, s -> calls[0]++); sessions.windowFocus(false, s -> calls[0]++);
        check(calls[0] == 1, "broken library lifecycle called JNI");
        RouteTracker routes = new RouteTracker(new int[]{3,1});
        check(!routes.changed(new int[]{1,3,3}), "initial/duplicate output set changed route");
        check(routes.changed(new int[]{1,4}), "output replacement was ignored");
        check(!routes.changed(new int[]{4,1}), "output ordering changed route");
        check(routes.changed(new int[]{}), "output removal was ignored");
        System.out.println("Platform Java dispatch checks passed");
    }
}
