add_library(heapsandroid_platform OBJECT platform.cpp)
target_include_directories(heapsandroid_platform PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}/../include" "${HL}/src" "${VENDOR}/sdl/include")
target_compile_definitions(heapsandroid_platform PRIVATE LIBHL_STATIC)
set_target_properties(heapsandroid_platform PROPERTIES POSITION_INDEPENDENT_CODE ON)
