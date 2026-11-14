package io.heaps.android;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.media.AudioAttributes;
import android.media.AudioDeviceCallback;
import android.media.AudioDeviceInfo;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowManager;
import java.util.concurrent.atomic.AtomicInteger;

/** Android callback threads touch Java/native state only, never HashLink objects. */
final class PlatformServices {
    private final HeapsActivity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final AudioManager audio;
    private final SensorManager sensorManager;
    private final Vibrator vibrator;
    private final Sensor[] sensors = new Sensor[2];
    private final Object sensorLock = new Object(), hapticLock = new Object(), focusLock = new Object();
    private static final AtomicInteger focusGenerations = new AtomicInteger();
    private final SessionDispatch sessions;
    private Resources resources;

    /** Every callback and every Android registration belongs to one immutable session. */
    private final class Resources {
        final SessionDispatch.Session session;
        final boolean[] requested = new boolean[2], registered = new boolean[2];
        final SensorEventListener sensorListener;
        final AudioDeviceCallback routeListener;
        final RouteTracker routes;
        final Runnable rehideSystemUi;
        boolean immersive = BuildConfig.DISPLAY_IMMERSIVE, keepAwake = BuildConfig.DISPLAY_KEEP_AWAKE;
        int focusGeneration;
        AudioManager.OnAudioFocusChangeListener focusListener;
        AudioFocusRequest focusRequest;
        boolean routeRegistered;
        Resources(SessionDispatch.Session session) {
            this.session = session;
            rehideSystemUi = () -> sessions.run(session, () -> reapplyDisplay(Resources.this));
            routes = new RouteTracker(outputIds());
            sensorListener = new SensorEventListener() {
                @Override public void onSensorChanged(SensorEvent event) { publishSensor(Resources.this, event); }
                @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {}
            };
            routeListener = new AudioDeviceCallback() {
                @Override public void onAudioDevicesAdded(AudioDeviceInfo[] devices) { routeChanged(Resources.this); }
                @Override public void onAudioDevicesRemoved(AudioDeviceInfo[] devices) { routeChanged(Resources.this); }
            };
        }
    }
    PlatformServices(HeapsActivity activity, NativeDispatch nativeDispatch) {
        this.activity = activity;
        audio = (AudioManager)activity.getSystemService(Context.AUDIO_SERVICE);
        sensorManager = (SensorManager)activity.getSystemService(Context.SENSOR_SERVICE);
        vibrator = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
        if (sensorManager != null) {
            sensors[0] = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
            sensors[1] = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
        }
        sessions = new SessionDispatch(nativeDispatch, new SessionDispatch.Publication() {
            public void start(long epoch, boolean foreground, boolean focus) { nativeStart(epoch, foreground, focus); }
            public void stop(long epoch) { nativeStop(epoch); }
        });
    }
    private static native void nativeStart(long epoch, boolean foreground, boolean windowFocus);
    private static native void nativeStop(long epoch);
    private static native void nativeForeground(long epoch, boolean foreground);
    private static native void nativeWindowFocus(long epoch, boolean focus);
    private static native void nativeBeginFocus(long epoch, int generation);
    private static native void nativeAudioFocus(long epoch, int generation, boolean focus);
    private static native void nativeAbandonFocus(long epoch, int generation);
    private static native void nativeSensorActive(long epoch, int kind, boolean active);
    private static native void nativeSensor(long epoch, int kind, double x, double y, double z, long timestampNs);
    private static native void nativeDisplay(long epoch, boolean immersive, boolean keepAwake);
    private static native void nativeInsets(long epoch, int left, int top, int right, int bottom);
    private static native void nativeRouteChanged(long epoch);

    void initialize() {
        synchronized (sessions) {
            SessionDispatch.Session session = sessions.start();
            if (session == null || (resources != null && resources.session == session)) return;
            Resources r = new Resources(session); resources = r;
            main.post(() -> sessions.run(session, () -> {
                View decor = activity.getWindow().getDecorView();
                decor.setOnApplyWindowInsetsListener((view, insets) -> {
                    sessions.run(session, () -> publishInsets(r, insets)); return insets;
                });
                reapplyDisplay(r);
                decor.requestApplyInsets();
                registerSensors(r);
                if (audio != null) {
                    try { audio.registerAudioDeviceCallback(r.routeListener, main); r.routeRegistered = true; }
                    catch (RuntimeException unavailable) { /* Output device monitoring is unavailable. */ }
                }
            }));
        }
    }
    void foreground(boolean value) {
        synchronized (sessions) {
            sessions.foreground(value, session -> {
                nativeForeground(session.epoch, value);
                Resources r = resources;
                if (r == null) return;
                if (!value) { abandonFocus(r); cancelVibrationLocked(); unregisterSensors(r); }
                else main.post(() -> sessions.run(session, () -> registerSensors(r)));
            });
        }
    }
    void windowFocus(boolean value) {
        synchronized (sessions) {
            sessions.windowFocus(value, session -> {
                nativeWindowFocus(session.epoch, value);
                if (!value && resources != null) { abandonFocus(resources); cancelVibrationLocked(); }
            });
        }
    }
    boolean requestAudioFocus() {
        synchronized (sessions) {
            Resources r = resources;
            if (r == null || !sessions.valid(r.session) || !sessions.foreground() || !sessions.windowFocus() || audio == null) return false;
            synchronized (focusLock) {
                abandonFocus(r);
                int generation = focusGenerations.updateAndGet(previous -> previous == Integer.MAX_VALUE ? previous : previous + 1);
                if (generation == Integer.MAX_VALUE) return false;
                r.focusGeneration = generation;
                nativeBeginFocus(r.session.epoch, generation);
                r.focusListener = change -> sessions.run(r.session, () -> {
                    synchronized (focusLock) {
                        if (r.focusGeneration == generation) nativeAudioFocus(r.session.epoch, generation, change == AudioManager.AUDIOFOCUS_GAIN);
                    }
                });
                int result;
                try {
                    if (Build.VERSION.SDK_INT >= 26) {
                        r.focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                            .setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                            .setAcceptsDelayedFocusGain(false).setOnAudioFocusChangeListener(r.focusListener, main).build();
                        result = audio.requestAudioFocus(r.focusRequest);
                    } else result = audio.requestAudioFocus(r.focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
                } catch (RuntimeException failure) { result = AudioManager.AUDIOFOCUS_REQUEST_FAILED; }
                if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { abandonFocus(r); return false; }
                nativeAudioFocus(r.session.epoch, generation, true);
                return true;
            }
        }
    }
    void abandonAudioFocus() {
        synchronized (sessions) { if (resources != null && sessions.valid(resources.session)) abandonFocus(resources); }
    }
    private void abandonFocus(Resources r) {
        synchronized (focusLock) {
            int generation = r.focusGeneration; r.focusGeneration = 0;
            if (generation != 0 && sessions.valid(r.session)) nativeAbandonFocus(r.session.epoch, generation);
            try {
                if (audio != null) {
                    if (Build.VERSION.SDK_INT >= 26 && r.focusRequest != null) audio.abandonAudioFocusRequest(r.focusRequest);
                    else if (r.focusListener != null) audio.abandonAudioFocus(r.focusListener);
                }
            } catch (RuntimeException ignored) { /* Native generation was invalidated first. */ }
            r.focusRequest = null; r.focusListener = null;
        }
    }
    boolean hapticsAvailable() {
        synchronized (sessions) {
            try { return sessions.valid(sessions.current()) && vibrator != null && vibrator.hasVibrator(); }
            catch (RuntimeException unavailable) { return false; }
        }
    }
    boolean vibrate(int milliseconds) {
        synchronized (sessions) {
            synchronized (hapticLock) {
                if (!sessions.foreground() || !sessions.windowFocus() || !hapticsAvailable()) return false;
                int duration = Math.max(1, Math.min(2000, milliseconds));
                try {
                    if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE));
                    else vibrator.vibrate(duration);
                    return true;
                } catch (RuntimeException unavailable) { return false; }
            }
        }
    }
    void cancelVibration() { synchronized (sessions) { cancelVibrationLocked(); } }
    private void cancelVibrationLocked() {
        synchronized (hapticLock) { try { if (vibrator != null) vibrator.cancel(); } catch (RuntimeException ignored) {} }
    }
    boolean sensorAvailable(int kind) {
        synchronized (sessions) { return sessions.valid(sessions.current()) && kind >= 0 && kind < 2 && sensors[kind] != null; }
    }
    boolean enableSensor(int kind) {
        synchronized (sessions) {
            if (!sensorAvailable(kind)) return false;
            Resources r = resources;
            synchronized (sensorLock) { r.requested[kind] = true; }
            main.post(() -> sessions.run(r.session, () -> registerSensors(r)));
            return true;
        }
    }
    void disableSensor(int kind) {
        synchronized (sessions) {
            Resources r = resources;
            if (kind < 0 || kind > 1 || r == null || !sessions.valid(r.session)) return;
            synchronized (sensorLock) {
                r.requested[kind] = false;
                if (r.registered[kind] && sensorManager != null) sensorManager.unregisterListener(r.sensorListener, sensors[kind]);
                r.registered[kind] = false; nativeSensorActive(r.session.epoch, kind, false);
            }
        }
    }
    private void registerSensors(Resources r) {
        if (!sessions.valid(r.session) || !sessions.foreground() || sensorManager == null) return;
        synchronized (sensorLock) {
            for (int kind = 0; kind < 2; kind++) if (r.requested[kind] && sensors[kind] != null) {
                try { if (!r.registered[kind]) r.registered[kind] = sensorManager.registerListener(r.sensorListener, sensors[kind], 20000, main); }
                catch (RuntimeException unavailable) { r.registered[kind] = false; }
                nativeSensorActive(r.session.epoch, kind, r.registered[kind]);
            }
        }
    }
    private void unregisterSensors(Resources r) {
        synchronized (sensorLock) {
            try { if (sensorManager != null) sensorManager.unregisterListener(r.sensorListener); } catch (RuntimeException ignored) {}
            for (int kind = 0; kind < 2; kind++) {
                r.registered[kind] = false;
                if (sessions.valid(r.session)) nativeSensorActive(r.session.epoch, kind, false);
            }
        }
    }
    private void publishSensor(Resources r, SensorEvent event) {
        sessions.run(r.session, () -> {
            if (!sessions.foreground() || event.values.length < 3) return;
            int kind = event.sensor == sensors[0] ? 0 : event.sensor == sensors[1] ? 1 : -1;
            if (kind < 0) return;
            synchronized (sensorLock) {
                if (r.requested[kind] && r.registered[kind]) nativeSensor(r.session.epoch, kind, event.values[0], event.values[1], event.values[2], event.timestamp);
            }
        });
    }
    private int[] outputIds() {
        if (audio == null) return new int[0];
        try {
            AudioDeviceInfo[] outputs = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS);
            int[] ids = new int[outputs.length];
            for (int i = 0; i < outputs.length; i++) ids[i] = outputs[i].getId();
            return ids;
        } catch (RuntimeException unavailable) { return new int[0]; }
    }
    private void routeChanged(Resources r) {
        sessions.run(r.session, () -> {
            if (r.routes.changed(outputIds())) { nativeRouteChanged(r.session.epoch); abandonFocus(r); }
        });
    }
    void applyImmersive(boolean value) { postDisplay(value, true); }
    void applyKeepAwake(boolean value) { postDisplay(value, false); }
    private void postDisplay(boolean value, boolean immersive) {
        synchronized (sessions) {
            Resources r = resources; if (r == null) return;
            main.post(() -> sessions.run(r.session, () -> {
                if (immersive) r.immersive = value; else r.keepAwake = value;
                reapplyDisplay(r);
            }));
        }
    }
    void reapplyDisplay() {
        synchronized (sessions) {
            Resources r = resources; if (r != null) main.post(() -> sessions.run(r.session, () -> reapplyDisplay(r)));
        }
    }
    void systemUiVisibilityChanged(int visibility) {
        synchronized (sessions) {
            Resources r = resources;
            int hidden = View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION;
            if (r == null || !sessions.valid(r.session) || !r.immersive || (visibility & hidden) == hidden) return;
            main.removeCallbacks(r.rehideSystemUi);
            main.postDelayed(r.rehideSystemUi, 2000);
        }
    }
    private void reapplyDisplay(Resources r) {
        View decor = activity.getWindow().getDecorView();
        if (r.immersive) {
            activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN);
            activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
            decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        } else {
            activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
            decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
        }
        if (r.keepAwake) activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        else activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        nativeDisplay(r.session.epoch, (activity.getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN) != 0,
            (activity.getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) != 0);
        WindowInsets insets = decor.getRootWindowInsets(); if (insets != null) publishInsets(r, insets);
    }
    private void publishInsets(Resources r, WindowInsets insets) {
        if (Build.VERSION.SDK_INT >= 30) {
            android.graphics.Insets safe = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
            nativeInsets(r.session.epoch, safe.left, safe.top, safe.right, safe.bottom); return;
        }
        int left = insets.getStableInsetLeft(), top = insets.getStableInsetTop();
        int right = insets.getStableInsetRight(), bottom = insets.getStableInsetBottom();
        if (Build.VERSION.SDK_INT >= 28 && insets.getDisplayCutout() != null) {
            left = Math.max(left, insets.getDisplayCutout().getSafeInsetLeft()); top = Math.max(top, insets.getDisplayCutout().getSafeInsetTop());
            right = Math.max(right, insets.getDisplayCutout().getSafeInsetRight()); bottom = Math.max(bottom, insets.getDisplayCutout().getSafeInsetBottom());
        }
        nativeInsets(r.session.epoch, left, top, right, bottom);
    }
    void cancelKeyboard() {
        synchronized (sessions) {
            Resources r = resources; if (r != null) main.post(() -> sessions.run(r.session, activity::hideIme));
        }
    }
    void shutdown() {
        synchronized (sessions) {
            Resources r = resources;
            sessions.stop(); // SDK inactive and native epoch invalid BEFORE Android resource cleanup.
            resources = null;
            if (r == null) return;
            abandonFocus(r); cancelVibrationLocked(); unregisterSensors(r);
            main.removeCallbacks(r.rehideSystemUi);
            try { if (audio != null && r.routeRegistered) audio.unregisterAudioDeviceCallback(r.routeListener); } catch (RuntimeException ignored) {}
            main.post(() -> sessions.cleanup(r.session, () -> {
                View decor = activity.getWindow().getDecorView();
                decor.setOnApplyWindowInsetsListener(null);
                activity.displayStopped();
                activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
                decor.requestApplyInsets();
                activity.hideIme();
            }));
        }
    }
    void destroy() { synchronized (sessions) { shutdown(); sessions.destroy(); } }
}
