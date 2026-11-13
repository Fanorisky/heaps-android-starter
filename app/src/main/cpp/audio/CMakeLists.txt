# Included by the host after main/hl and the pinned dependencies are defined.
# LGPL OpenAL Soft is deliberately a separate packaged shared library.
set(LIBTYPE SHARED CACHE STRING "OpenAL library type" FORCE)
foreach(OPTION UTILS EXAMPLES TESTS INSTALL INSTALL_CONFIG INSTALL_HRTF_DATA
        INSTALL_AMBDEC_PRESETS INSTALL_EXAMPLES INSTALL_UTILS UPDATE_BUILD_VERSION EAX)
    set(ALSOFT_${OPTION} OFF CACHE BOOL "" FORCE)
endforeach()
foreach(BACKEND PIPEWIRE PULSEAUDIO ALSA OSS SOLARIS SNDIO WINMM DSOUND WASAPI
        OTHERIO JACK COREAUDIO OBOE PORTAUDIO SDL2 SDL3 WAVE)
    set(ALSOFT_BACKEND_${BACKEND} OFF CACHE BOOL "" FORCE)
endforeach()
set(ALSOFT_BACKEND_OPENSL ON CACHE BOOL "" FORCE)
set(ALSOFT_REQUIRE_OPENSL ON CACHE BOOL "" FORCE)
add_subdirectory("${VENDOR}/openal" "${CMAKE_CURRENT_BINARY_DIR}/openal" EXCLUDE_FROM_ALL)

add_library(heapsandroid_audio OBJECT
    "${CMAKE_CURRENT_LIST_DIR}/gate.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/gate_controller.cpp"
    "${HL}/libs/openal/openal.c")
target_include_directories(heapsandroid_audio PRIVATE
    "${HL}/src" "${VENDOR}/openal/include" "${REPO}/app/src/main/cpp/include")
target_compile_definitions(heapsandroid_audio PRIVATE LIBHL_STATIC HEAPS_ANDROID_AUDIO_GATE openal_soft)
# hlopenal declares extension import variables with the same names as OpenAL
# functions. Hidden visibility prevents those data symbols from interposing the
# real shared-library functions; primitives remain directly reachable by HLC.
set_source_files_properties("${HL}/libs/openal/openal.c" PROPERTIES COMPILE_OPTIONS "-fvisibility=hidden")
target_link_libraries(heapsandroid_audio PRIVATE hl OpenAL)
target_link_options(OpenAL PRIVATE "-Wl,-z,max-page-size=16384")
