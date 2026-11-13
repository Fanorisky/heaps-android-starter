#!/usr/bin/env python3
"""Verify the actual artifact's signature, native architectures and host/audio exports."""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import tempfile
import zipfile
from apk_info import apk_info

ROOT = Path(__file__).resolve().parents[1]
SDK = Path(os.environ.get('ANDROID_HOME', '/opt/android-sdk'))
NDK_BIN = SDK / 'ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin'
parser = argparse.ArgumentParser()
parser.add_argument('apk', nargs='?', default=str(ROOT / 'dist/heaps-android-proof.apk'))
parser.add_argument('--expected-cert', help='Expected stable certificate SHA256')
args = parser.parse_args()
APK = Path(args.apk).resolve()
OUT = ROOT / 'dist/verification'
OUT.mkdir(parents=True, exist_ok=True)
def run(*args): return subprocess.check_output(list(map(str, args)), text=True, timeout=30)
info = apk_info(APK)
assert info['minSdk'] == 24, info
assert set(info['abis']) == {'armeabi-v7a', 'arm64-v8a', 'x86_64'}, info
assert info['activity'] == 'io.heaps.android.HeapsActivity', info
signature = run(SDK / 'build-tools/34.0.0/apksigner', 'verify', '--verbose', '--print-certs', APK)
cert = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)', signature).group(1)
if args.expected_cert: assert cert == args.expected_cert.lower().replace(':',''), 'Test signing identity changed'
report = {'application': info, 'certificateSha256': cert, 'libraries': {}}
with zipfile.ZipFile(APK) as archive, tempfile.TemporaryDirectory() as tmp:
    for abi, machine in [('armeabi-v7a','ARM'), ('arm64-v8a','AArch64'), ('x86_64','Advanced Micro Devices X86-64')]:
        report['libraries'][abi] = {}
        for library in ['libmain.so','libhl.so','libSDL2.so','libopenal.so','libc++_shared.so']:
            path = Path(tmp) / abi / library
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(archive.read('lib/' + abi + '/' + library))
            header = run(NDK_BIN / 'llvm-readelf', '-h', path)
            found = re.search(r'^\s*Machine:\s*(.+)$', header, re.M).group(1).strip()
            assert found == machine and ('ELF32' if abi=='armeabi-v7a' else 'ELF64') in header, (abi,library,header)
            symbols = run(NDK_BIN / 'llvm-nm', '-D', '--defined-only', path)
            if library == 'libmain.so':
                for name in ['SDL_main','Main_init','heapsandroid_audio_get_state','Java_io_heaps_android_PlatformServices_nativeForeground']:
                    assert re.search(r'\b'+re.escape(name)+r'$', symbols, re.M), (library,name)
                assert 'JNI_OnLoad' not in symbols
                assert not re.search(r'\b[BDRbd] (?:al|alc)[A-Z]\w*$', symbols, re.M), 'OpenAL binding globals interpose audio functions'
            elif library == 'libhl.so':
                assert 'JNI_OnLoad' in symbols and 'hl_sys_special' in symbols
            elif library == 'libopenal.so':
                for name in ['alcOpenDevice','alcDevicePauseSOFT','alcDeviceResumeSOFT','alSourcePlay']:
                    assert re.search(r'\b'+name+r'$', symbols,re.M), (library,name)
            report['libraries'][abi][library] = {'bytes': path.stat().st_size,'machine':machine}
(OUT/'signature.txt').write_text(signature)
(OUT/'apk.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS APK: '+info['package']+' '+info['versionName']+', ARM32/ARM64/x86_64, native platform/audio, valid certificate '+cert)
