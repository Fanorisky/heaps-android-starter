package io.heaps.android;

import android.content.Context;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import org.libsdl.app.SDLActivity;

/** Fixed host namespace; the applicationId is configured independently. */
public final class HeapsActivity extends SDLActivity {
    private static volatile HeapsActivity current;
    private PlatformServices services;
    private volatile boolean librariesReady;
    private final NativeDispatch nativeDispatch = new NativeDispatch(() -> librariesReady && !mBrokenLibraries);

    @Override public void onCreate(Bundle savedInstanceState) {
        current = this;
        services = new PlatformServices(this, nativeDispatch);
        super.onCreate(savedInstanceState);
        librariesReady = !mBrokenLibraries;
    }
    public static Context getContext() { return current; }
    @Override protected String[] getLibraries() {
        return new String[] {"SDL2", "hl", "openal", "main"};
    }
    @Override protected void onResume() {
        services.foreground(true);
        super.onResume();
    }
    @Override protected void onPause() {
        // Silence the native device before SDL can suspend the game thread.
        services.foreground(false);
        hideIme();
        super.onPause();
    }
    @Override public void onWindowFocusChanged(boolean hasFocus) {
        if (services != null) services.windowFocus(hasFocus);
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus && services != null) services.reapplyDisplay();
    }
    @Override protected void onDestroy() {
        if (services != null) services.destroy();
        super.onDestroy();
        librariesReady = false;
        if (current == this) current = null;
    }
    void hideIme() {
        View input = (View)mTextEdit;
        if (input != null) {
            InputMethodManager manager = (InputMethodManager)getSystemService(INPUT_METHOD_SERVICE);
            if (manager != null) manager.hideSoftInputFromWindow(input.getWindowToken(), 0);
            input.clearFocus();
            input.setVisibility(View.GONE);
            if (input.getParent() instanceof ViewGroup) ((ViewGroup)input.getParent()).removeView(input);
            mTextEdit = null;
        }
    }
    // Called synchronously through JNI from the SDL thread; UI changes are posted.
    public void cancelKeyboard() { services.cancelKeyboard(); }
    public boolean configuredImmersive() { return BuildConfig.DISPLAY_IMMERSIVE; }
    public String configuredOrientation() { return BuildConfig.APP_ORIENTATION; }
    public void initializeServices() { services.initialize(); }
    public void shutdownServices() { services.shutdown(); }
    public boolean requestAudioFocus() { return services.requestAudioFocus(); }
    public void abandonAudioFocus() { services.abandonAudioFocus(); }
    public boolean hapticsAvailable() { return services.hapticsAvailable(); }
    public boolean vibrate(int milliseconds) { return services.vibrate(milliseconds); }
    public void cancelVibration() { services.cancelVibration(); }
    public boolean sensorAvailable(int kind) { return services.sensorAvailable(kind); }
    public boolean enableSensor(int kind) { return services.enableSensor(kind); }
    public void disableSensor(int kind) { services.disableSensor(kind); }
    public void applyImmersive(boolean value) { services.applyImmersive(value); }
    public void applyKeepAwake(boolean value) { services.applyKeepAwake(value); }
    public String deviceModel() { return android.os.Build.MODEL; }
    public String supportedAbis() { return String.join(",", android.os.Build.SUPPORTED_ABIS); }
    public int deviceSdk() { return android.os.Build.VERSION.SDK_INT; }
    public String filesPath() { return getFilesDir().getAbsolutePath(); }
    public String cachePath() { return getCacheDir().getAbsolutePath(); }
}
