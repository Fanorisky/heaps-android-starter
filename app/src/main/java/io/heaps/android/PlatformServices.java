package io.heaps.android;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.media.AudioAttributes;
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
final class PlatformServices implements SensorEventListener {
    private final HeapsActivity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final AudioManager audio;
    private final SensorManager sensorManager;
    private final Vibrator vibrator;
    private final Sensor[] sensors = new Sensor[2];
    private final boolean[] requested = new boolean[2];
    private final boolean[] registered = new boolean[2];
    private final Object sensorLock = new Object();
    private final Object hapticLock = new Object();
    private final Object focusLock = new Object();
    private static final AtomicInteger generations = new AtomicInteger();
    private volatile boolean alive = true;
    private volatile boolean foreground;
    private volatile boolean immersive;
    private volatile boolean keepAwake;
    private int activeGeneration;
    private AudioManager.OnAudioFocusChangeListener focusListener;
    private AudioFocusRequest focusRequest;

    PlatformServices(HeapsActivity activity) {
        this.activity = activity;
        audio = (AudioManager)activity.getSystemService(Context.AUDIO_SERVICE);
        sensorManager = (SensorManager)activity.getSystemService(Context.SENSOR_SERVICE);
        vibrator = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
        if (sensorManager != null) {
            sensors[0] = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
            sensors[1] = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
        }
    }
    private static native void nativeForeground(boolean foreground);
    private static native void nativeWindowFocus(boolean focus);
    private static native void nativeBeginFocus(int generation);
    private static native void nativeAudioFocus(int generation, boolean focus);
    private static native void nativeAbandonFocus(int generation);
    private static native void nativeSensorActive(int kind, boolean active);
    private static native void nativeSensor(int kind, double x, double y, double z, long timestampNs);
    private static native void nativeDisplay(boolean immersive, boolean keepAwake);
    private static native void nativeInsets(int left, int top, int right, int bottom);

    void initialize() {
        main.post(() -> {
            if (!alive) return;
            immersive = BuildConfig.DISPLAY_IMMERSIVE;
            keepAwake = BuildConfig.DISPLAY_KEEP_AWAKE;
            View decor = activity.getWindow().getDecorView();
            decor.setOnApplyWindowInsetsListener((view, insets) -> {
                publishInsets(insets); return insets;
            });
            reapplyDisplay();
            decor.requestApplyInsets();
            registerRequestedSensors();
        });
    }
    void foreground(boolean value) {
        if (!alive) return;
        foreground = value;
        nativeForeground(value);
        if (!value) {
            abandonAudioFocus();
            cancelVibration();
            unregisterSensors();
        } else registerRequestedSensors();
    }
    void windowFocus(boolean value) { if (alive) nativeWindowFocus(value); }

    boolean requestAudioFocus() {
        synchronized (focusLock) {
            if (!alive || !foreground || audio == null) return false;
            abandonAudioFocusLocked();
            int generation = generations.updateAndGet(previous -> previous == Integer.MAX_VALUE ? previous : previous + 1);
            if (generation == Integer.MAX_VALUE) return false;
            activeGeneration = generation;
            nativeBeginFocus(generation);
            focusListener = change -> handleAudioFocus(generation, change);
            int result;
            try {
                if (Build.VERSION.SDK_INT >= 26) {
                    focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                        .setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                        .setAcceptsDelayedFocusGain(false)
                        .setOnAudioFocusChangeListener(focusListener, main).build();
                    result = audio.requestAudioFocus(focusRequest);
                } else {
                    result = audio.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
                }
            } catch (RuntimeException failure) { result = AudioManager.AUDIOFOCUS_REQUEST_FAILED; }
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                abandonAudioFocusLocked(); return false;
            }
            nativeAudioFocus(generation, true);
            return true;
        }
    }
    private void handleAudioFocus(int generation, int change) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            main.post(() -> handleAudioFocus(generation, change)); return;
        }
        synchronized (focusLock) {
            if (!alive || activeGeneration != generation) return;
            // Ducking also pauses: recovery still requires explicit playback intent.
            nativeAudioFocus(generation, change == AudioManager.AUDIOFOCUS_GAIN);
        }
    }
    void abandonAudioFocus() { synchronized (focusLock) { abandonAudioFocusLocked(); } }
    private void abandonAudioFocusLocked() {
        int generation = activeGeneration;
        activeGeneration = 0;
        if (generation != 0) nativeAbandonFocus(generation);
        try {
            if (audio != null) {
                if (Build.VERSION.SDK_INT >= 26 && focusRequest != null) audio.abandonAudioFocusRequest(focusRequest);
                else if (focusListener != null) audio.abandonAudioFocus(focusListener);
            }
        } catch (RuntimeException ignored) { /* Native generation is already invalidated. */ }
        focusRequest = null; focusListener = null;
    }
    boolean hapticsAvailable() {
        try { return alive && vibrator != null && vibrator.hasVibrator(); }
        catch (RuntimeException unavailable) { return false; }
    }
    boolean vibrate(int milliseconds) {
        synchronized (hapticLock) {
        if (!foreground || !hapticsAvailable()) return false;
        int duration = Math.max(1, Math.min(2000, milliseconds));
        try {
            if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE));
            else vibrator.vibrate(duration);
            return true;
        } catch (RuntimeException unavailable) { return false; }
        }
    }
    void cancelVibration() {
        synchronized (hapticLock) {
            try { if (vibrator != null) vibrator.cancel(); } catch (RuntimeException ignored) {}
        }
    }
    boolean sensorAvailable(int kind) { return alive && kind >= 0 && kind < 2 && sensors[kind] != null; }
    boolean enableSensor(int kind) {
        if (!sensorAvailable(kind)) return false;
        synchronized (sensorLock) { requested[kind] = true; }
        main.post(this::registerRequestedSensors);
        return true;
    }
    void disableSensor(int kind) {
        if (kind < 0 || kind > 1) return;
        synchronized (sensorLock) { requested[kind] = false; }
        main.post(() -> {
            synchronized (sensorLock) {
                if (requested[kind]) return;
                if (registered[kind]) sensorManager.unregisterListener(this, sensors[kind]);
                registered[kind] = false; nativeSensorActive(kind, false);
            }
        });
    }
    private void registerRequestedSensors() {
        if (Looper.myLooper() != Looper.getMainLooper()) { main.post(this::registerRequestedSensors); return; }
        if (!alive || !foreground || sensorManager == null) return;
        synchronized (sensorLock) {
            for (int kind = 0; kind < 2; kind++) if (requested[kind] && sensors[kind] != null) {
                if (!registered[kind]) registered[kind] = sensorManager.registerListener(this, sensors[kind], 20000, main);
                nativeSensorActive(kind, registered[kind]);
            }
        }
    }
    private void unregisterSensors() {
        if (Looper.myLooper() != Looper.getMainLooper()) { main.post(this::unregisterSensors); return; }
        synchronized (sensorLock) {
            if (sensorManager != null) sensorManager.unregisterListener(this);
            for (int kind = 0; kind < 2; kind++) {registered[kind] = false; nativeSensorActive(kind, false);}
        }
    }
    @Override public void onSensorChanged(SensorEvent event) {
        if (!alive || !foreground || event.values.length < 3) return;
        int kind = event.sensor == sensors[0] ? 0 : event.sensor == sensors[1] ? 1 : -1;
        if (kind < 0) return;
        synchronized (sensorLock) {
            if (requested[kind] && registered[kind]) nativeSensor(kind, event.values[0], event.values[1], event.values[2], event.timestamp);
        }
    }
    @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {}
    void applyImmersive(boolean value) { main.post(() -> { if (alive) { immersive = value; reapplyDisplay(); } }); }
    void applyKeepAwake(boolean value) { main.post(() -> { if (alive) { keepAwake = value; reapplyDisplay(); } }); }
    void reapplyDisplay() {
        if (!alive) return;
        if (Looper.myLooper() != Looper.getMainLooper()) { main.post(this::reapplyDisplay); return; }
        View decor = activity.getWindow().getDecorView();
        if (immersive) {
            activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN);
            activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
            decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        } else {
            activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
            decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
        }
        if (keepAwake) activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        else activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        nativeDisplay((activity.getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN) != 0,
            (activity.getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) != 0);
        WindowInsets insets = decor.getRootWindowInsets();
        if (insets != null) publishInsets(insets);
    }
    private void publishInsets(WindowInsets insets) {
        if (Build.VERSION.SDK_INT >= 30) {
            android.graphics.Insets safe = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
            nativeInsets(safe.left, safe.top, safe.right, safe.bottom); return;
        }
        int left = insets.getStableInsetLeft(), top = insets.getStableInsetTop();
        int right = insets.getStableInsetRight(), bottom = insets.getStableInsetBottom();
        if (Build.VERSION.SDK_INT >= 28 && insets.getDisplayCutout() != null) {
            left = Math.max(left, insets.getDisplayCutout().getSafeInsetLeft());
            top = Math.max(top, insets.getDisplayCutout().getSafeInsetTop());
            right = Math.max(right, insets.getDisplayCutout().getSafeInsetRight());
            bottom = Math.max(bottom, insets.getDisplayCutout().getSafeInsetBottom());
        }
        nativeInsets(left, top, right, bottom);
    }
    void shutdown() {
        if (!alive) return;
        foreground(false);
        alive = false;
        synchronized (sensorLock) { requested[0] = requested[1] = false; }
        main.post(() -> { unregisterSensors(); activity.hideIme(); });
    }
}
