# Pinned dependencies

`dependencies.lock.json` records exact archive URLs, revisions and SHA256 hashes. Setup verifies cached/downloaded archives before extracting ignored `vendor/` sources and applies the explicit patches idempotently. Haxelib mappings are local to the template.

HashLink1.15 supplies native SDL and format bindings. The SDK also builds its `hlopenal` binding against OpenAL Soft1.24.3. OpenAL's OpenSL ES output is a real Android backend and `libopenal.so` is packaged separately. Extension import-pointer globals in the HL binding are hidden, avoiding interposition of OpenAL functions.

OpenAL Soft is LGPL; copies of its license and bundled-code notices are in `licenses/openal/`. Its exact corresponding source is the `openal` archive in the lock file:

https://codeload.github.com/kcat/openal-soft/tar.gz/dc7d7054a5b4f3bec1dc23a42fd616a0847af948

Our build options are in `app/src/main/cpp/audio/CMakeLists.txt`. OpenAL source is unmodified. The public template plus pinned archives allows rebuilding/replacing the separate shared library. Keep these notices/source information with distributed binaries.

PNG/zlib/TurboJPEG/Ogg/Vorbis supply real image/audio format decoding. HashLink's retained native mesh utilities are built from their upstream sources. HashLink's official non-Windows `ui_stub.c` covers desktop dialog/sentinel references; game and proof screens are rendered in Heaps.

GameBase and its additional Haxe dependencies are pinned alongside the native sources. Import provenance and Android adaptations are documented in [gamebase.md](gamebase.md).

Other dependency license copies are under `licenses/`. Original generated audio fixture authorship/license information is in `res/android/LICENSE.txt`. Template code is MIT; dependencies retain their respective licenses.
