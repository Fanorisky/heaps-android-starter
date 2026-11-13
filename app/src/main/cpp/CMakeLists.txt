cmake_minimum_required(VERSION 3.20)
project(neondrift C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
get_filename_component(REPO "${CMAKE_CURRENT_LIST_DIR}/../../../.." ABSOLUTE)
set(VENDOR "${REPO}/vendor")
set(HL "${VENDOR}/hashlink")

# Build upstream libraries locally; never discover host binaries while cross-compiling.
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SDL_SHARED ON CACHE BOOL "" FORCE)
set(SDL_STATIC OFF CACHE BOOL "" FORCE)
set(SDL_TEST OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory("${VENDOR}/sdl" sdl EXCLUDE_FROM_ALL)

add_subdirectory("${VENDOR}/zlib" zlib EXCLUDE_FROM_ALL)
add_library(ZLIB::ZLIB ALIAS zlibstatic)
set(ZLIB_LIBRARY zlibstatic CACHE STRING "" FORCE)
set(ZLIB_INCLUDE_DIR "${VENDOR}/zlib" CACHE PATH "" FORCE)
set(SKIP_INSTALL_ALL ON CACHE BOOL "" FORCE)
set(PNG_SHARED OFF CACHE BOOL "" FORCE)
set(PNG_STATIC ON CACHE BOOL "" FORCE)
set(PNG_TESTS OFF CACHE BOOL "" FORCE)
set(PNG_TOOLS OFF CACHE BOOL "" FORCE)
add_subdirectory("${VENDOR}/png" png EXCLUDE_FROM_ALL)

set(ENABLE_SHARED OFF CACHE BOOL "" FORCE)
set(ENABLE_STATIC ON CACHE BOOL "" FORCE)
set(WITH_SIMD OFF CACHE BOOL "" FORCE)
set(WITH_TURBOJPEG ON CACHE BOOL "" FORCE)
include(ExternalProject)
ExternalProject_Add(jpeg-build
    SOURCE_DIR "${VENDOR}/jpeg"
    BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/jpeg"
    CMAKE_ARGS
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -DANDROID_ABI=${ANDROID_ABI}
        -DANDROID_PLATFORM=${ANDROID_PLATFORM}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_SIMD=OFF
        -DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}
    BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target turbojpeg-static --parallel 2
    INSTALL_COMMAND ""
    BUILD_BYPRODUCTS "${CMAKE_CURRENT_BINARY_DIR}/jpeg/libturbojpeg.a")
add_library(turbojpeg-static STATIC IMPORTED GLOBAL)
set_target_properties(turbojpeg-static PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/jpeg/libturbojpeg.a")
add_dependencies(turbojpeg-static jpeg-build)
add_subdirectory("${VENDOR}/ogg" ogg EXCLUDE_FROM_ALL)
set(OGG_LIBRARY ogg CACHE STRING "" FORCE)
set(OGG_INCLUDE_DIR "${VENDOR}/ogg/include" CACHE PATH "" FORCE)
add_subdirectory("${VENDOR}/vorbis" vorbis EXCLUDE_FROM_ALL)

# HashLink runtime (no bytecode VM/JIT): generated HLC calls these functions directly.
set(PCRE_NAMES
    auto_possess chartables compile config context convert dfa_match error extuni
    find_bracket jit_compile maketables match match_data newline ord2utf pattern_info
    script_run serialize string_utils study substitute substring tables ucd valid_utf xclass)
set(PCRE_SOURCES)
foreach(NAME IN LISTS PCRE_NAMES)
    list(APPEND PCRE_SOURCES "${HL}/include/pcre/pcre2_${NAME}.c")
endforeach()
file(GLOB HL_STD CONFIGURE_DEPENDS "${HL}/src/std/*.c")
add_library(hl SHARED "${HL}/src/gc.c" ${HL_STD} ${PCRE_SOURCES})
target_include_directories(hl PUBLIC "${HL}/src" PRIVATE "${HL}/include/pcre")
target_compile_definitions(hl PRIVATE LIBHL_EXPORTS HAVE_CONFIG_H PCRE2_CODE_UNIT_WIDTH=16
    HL_ANDROID_ACTIVITY="io/heaps/android/HeapsActivity")
target_link_libraries(hl PRIVATE m dl log)

# Haxe's generated game.c includes hlc_main.c, which supplies SDL_main on mobile.
# ui_stub.c is HashLink's official non-Windows UI implementation, used for error
# reporting/sentinel references. The game implements its UI entirely in Heaps.
file(GLOB HEAPS_MESH_SOURCES CONFIGURE_DEPENDS "${HL}/include/meshoptimizer/*.cpp")
add_library(main SHARED
    ${HEAPS_MESH_SOURCES}
    "${HL}/libs/heaps/meshoptimizer.cpp" "${HL}/libs/heaps/vhacd.cpp"
    "${HL}/libs/heaps/mikkt.c"
    "${REPO}/build/hlc/game.c"
    "${HL}/libs/sdl/sdl.c" "${HL}/libs/sdl/gl.c"
    "${HL}/libs/ui/ui_stub.c"
    "${HL}/libs/fmt/fmt.c" "${HL}/libs/fmt/sha1.c"
    "${HL}/libs/fmt/dxt.c" "${HL}/libs/fmt/mikkt.c"
    "${HL}/include/mikktspace/mikktspace.c")
target_include_directories(main PRIVATE
    "${REPO}/build/hlc" "${HL}/src" "${HL}/include/minimp3" "${HL}/include/mikktspace" "${HL}/include/meshoptimizer" "${HL}/include/vhacd"
    "${VENDOR}/jpeg/src" "${CMAKE_CURRENT_BINARY_DIR}/jpeg"
    "${VENDOR}/png" "${CMAKE_CURRENT_BINARY_DIR}/png")
target_compile_definitions(main PRIVATE LIBHL_STATIC HL_SDL)
target_link_libraries(main PRIVATE hl SDL2 png_static zlibstatic turbojpeg-static vorbisfile vorbisenc vorbis GLESv3 EGL log m dl)
target_link_options(main PRIVATE "-Wl,--no-undefined" "-Wl,-z,max-page-size=16384")
target_link_options(hl PRIVATE "-Wl,-z,max-page-size=16384")

# Reusable Android platform/audio fragments expose object libraries.
add_subdirectory(platform)
add_subdirectory(audio)
target_sources(main PRIVATE $<TARGET_OBJECTS:heapsandroid_platform> $<TARGET_OBJECTS:heapsandroid_audio>)
target_link_libraries(main PRIVATE OpenAL)
