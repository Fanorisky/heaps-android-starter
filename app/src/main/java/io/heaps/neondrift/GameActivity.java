package io.heaps.neondrift;

import android.content.Context;
import android.os.Bundle;
import org.libsdl.app.SDLActivity;

/** Android host for the ahead-of-time compiled Heaps game. */
public final class GameActivity extends SDLActivity {
    private static GameActivity current;

    @Override public void onCreate(Bundle savedInstanceState) {
        current = this;
        super.onCreate(savedInstanceState);
    }

    public static Context getContext() { return current; }

    @Override protected String[] getLibraries() {
        return new String[] { "SDL2", "hl", "main" };
    }

    @Override protected void onDestroy() {
        super.onDestroy();
        if (current == this) current = null;
    }
}
