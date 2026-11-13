# Pinned dependencies

`dependencies.lock.json` pins upstream archive URLs, revisions and SHA-256 hashes. `scripts/setup-toolchain.sh` verifies each cached/downloaded archive before extracting it under ignored `vendor/`. Haxelib mappings are local to this repository.

HashLink 1.15 uses SDL2; its native SDL and format bindings are compiled with the generated game C. Format decoding uses pinned PNG, zlib, TurboJPEG, Ogg and Vorbis libraries. No OpenAL library is linked. This small game currently uses no audio assets. HashLink's official `ui_stub.c` provides its non-Windows desktop-dialog/sentinel fallback; game screens are Heaps scenes. We do not replace rendering, input, storage or gameplay natives with dummy implementations.

License copies are in `licenses/`. The format library's BSD license is copied from its source header. HashLink additionally bundles PCRE2, minimp3 and MikkTSpace (license included in its source header). SDL includes third-party components under its own source tree; consult their original headers/licenses when redistributing modified components. Gradle wrapper is Apache-2.0 software from the Gradle project.

Any changes to upstream sources are recorded under `patches/` and applied idempotently by setup.
