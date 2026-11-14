package io.heaps.android;
/** Test-only host: exercise SDL's real library-load failure screen. */
public final class BrokenLibrariesActivity extends HeapsActivity {
    @Override protected String[] getLibraries() {
        return new String[] {"SDL2", "hl", "openal", "heaps_missing_test_library"};
    }
}
