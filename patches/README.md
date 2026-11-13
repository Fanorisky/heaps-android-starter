# Reproducible compatibility patches

Setup applies these patches in order and recognizes already-applied patches. Source archives remain checksum-pinned.

1. **Heaps hlsdl version guards.** Current Heaps references GPU readback and elapsed-time query APIs absent from hlsdl1.15. On that version, these optional calls throw an explicit unsupported-version error; ordinary 2D rendering is unchanged.
2. **HashLink Android native support.** Android's backend includes the GLES3.2 declaration header for the real APIs compiled into the bindings. GLES does not provide desktop `glShaderStorageBlockBinding`; that optional call reports an unsupported-platform error. AndroidAPI24 lacks libc's API33 `backtrace` APIs, so the entry code uses `_Unwind_Backtrace` and `dladdr` for real stack capture/symbol resolution.
3. **Haxe/C SDL entry.** Modern Haxe code generation no longer defines the legacy `sdl__Sdl__val` macro tested by HashLink1.15. CMake explicitly selects `HL_SDL`, causing the upstream entry code to include SDL_main.h and export SDL_main.
4. **ARM64 debugger trap.** Backport an ARM64 `brk` breakpoint instruction before the old Linux/x86 `int3` branch. This preserves debugger trapping instead of disabling it.

Native format and mesh bindings use upstream implementations. HashLink's official non-Windows UI fallback is linked for its desktop error-dialog/sentinel references; the game's visible UI is implemented in Heaps.

5. **Private storage JNI.** Correct Context.getFilesDir to its no-argument signature, invoke no-argument methods without an extra argument, and return unavailable storage safely on JNI lookup/call errors. The original HashLink1.15 implementation used the getExternalFilesDir signature for both paths.

6. **Heaps vec4 uniform count.** Shader buffer sizes are vec4 counts (the backing float buffer is size×4). glUniform4fv expects vec4 count. Correct the caller to pass size, avoiding GL_INVALID_OPERATION and blank output when a single-vec4 parameter uniform is used. Native uniform APIs retain their original contract.

7. **Android fullscreen.** Set SDL_WINDOW_FULLSCREEN when creating the Android SDL window, so SDL does not override the fullscreen activity theme with a windowed surface. This gives the game and touch mapping the same full-display viewport.
