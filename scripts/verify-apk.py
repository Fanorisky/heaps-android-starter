#!/usr/bin/env python3
"""Check signatures, architectures, and native startup symbols in the actual APK."""
from pathlib import Path
import json
import os
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SDK = Path(os.environ.get('ANDROID_HOME', '/opt/android-sdk'))
NDK_BIN = SDK / 'ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin'
APK = ROOT / 'dist/neon-drift-debug.apk'
OUT = ROOT / 'dist/verification'
OUT.mkdir(parents=True, exist_ok=True)

def run(*args):
    return subprocess.check_output(list(map(str, args)), text=True, timeout=30)

signature = run(SDK / 'build-tools/34.0.0/apksigner', 'verify', '--verbose', APK)
report = {}
with zipfile.ZipFile(APK) as archive, tempfile.TemporaryDirectory() as tmp:
    for abi, machine in [('arm64-v8a', 'AArch64'), ('x86_64', 'Advanced Micro Devices X86-64')]:
        report[abi] = {}
        for library in ['libmain.so', 'libhl.so', 'libSDL2.so', 'libc++_shared.so']:
            path = Path(tmp) / abi / library
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(archive.read('lib/' + abi + '/' + library))
            header = run(NDK_BIN / 'llvm-readelf', '-h', path)
            assert machine in header, (abi, library, header)
            symbols = run(NDK_BIN / 'llvm-nm', '-D', '--defined-only', path)
            if library == 'libmain.so':
                assert ' T SDL_main\n' in symbols and 'JNI_OnLoad' not in symbols, library
                assert 'Main_init' in symbols, 'Compiled Heaps game is absent'
            if library == 'libhl.so':
                assert ' T JNI_OnLoad\n' in symbols and 'hl_sys_special' in symbols, library
            report[abi][library] = {'bytes': path.stat().st_size, 'machine': machine}
(OUT / 'signature.txt').write_text(signature)
(OUT / 'apk.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS APK: valid signature, ARM64+x86_64 native game, SDL_main and private-storage JNI')
