Run `haxe platform-test.hxml` from the repository root for pure lifecycle,
orientation/haptic normalization and exact 64-bit sensor decoding checks.
Run `bash tests/platform/run-native.sh` after dependency extraction/patching for
full ASCII/Unicode/emoji UTF8 commits, malformed/truncated replacements,
bounded callback queues, sensor registration/background preservation,
double-buffer coherence during concurrent publication and display-state checks.
ASan/UBSan are enabled by default; set `SANITIZE=0` on unsupported hosts.

`ApiCompile.hx` is compile-only against real Heaps, HashLink, hlsdl and hlopenal:

```
haxe -cp lib -cp tests/platform -lib heaps -lib hlsdl -lib hlopenal -lib format \
  -main ApiCompile -D hl-ver=1.15.0 -D android -D no-compilation \
  -hl /tmp/heaps-platform-hlc/platform.c
```

These host checks do not exercise Android/JNI, a real IME, sensors, vibration,
audio focus or applied window flags. APK/emulator/device checks establish those
behaviors; `ApiCompile` must not be executed as a hardware proof.
