#!/usr/bin/env python3
"""Verify the debug APK on a connected Android emulator and retain evidence."""
from pathlib import Path
import json
import os
import re
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'io.heaps.neondrift'
ADB = str(Path(os.environ.get('ANDROID_HOME', '/opt/android-sdk')) / 'platform-tools/adb')
OUT = ROOT / 'dist/verification'
OUT.mkdir(parents=True, exist_ok=True)


def adb(*args, binary=False):
    return subprocess.check_output([ADB, *args], timeout=30, text=not binary)


def logs():
    return adb('logcat', '-d', '-v', 'brief', 'hl:D', 'AndroidRuntime:E', 'libc:F', '*:S')


def last_state():
    matches = re.findall(r'Neon Drift: phase=(\w+) score=(\d+) best=(\d+) remaining=(\d+)', logs())
    return dict(zip(('phase', 'score', 'best', 'remaining'), matches[-1])) if matches else None


def wait_phase(phases, seconds=15):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        state = last_state()
        if state and state['phase'] in phases:
            return state
        current_log = logs()
        if 'Fatal signal' in current_log or 'FATAL EXCEPTION' in current_log:
            raise AssertionError('Game crashed: ' + current_log)
        time.sleep(0.5)
    raise AssertionError('Expected ' + str(phases) + ', got ' + str(last_state()))


def screenshot(name):
    (OUT / (name + '.png')).write_bytes(adb('exec-out', 'screencap', '-p', binary=True))


def verify_title_rendering():
    # Raw screencap avoids an image-library dependency. The title's cyan graphics
    # distinguish a rendered Heaps scene from the previous blank background bug.
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        raw = adb('exec-out', 'screencap', binary=True)
        width, height, pixel_format = struct.unpack_from('<III', raw)
        stride = 4 if pixel_format in (1, 2) else 3 if pixel_format == 3 else 0
        assert stride, 'Unsupported raw screenshot pixel format: ' + str(pixel_format)
        pixels = raw[len(raw) - width * height * stride:]
        cyan = sum(1 for r, g, b in zip(pixels[0::stride], pixels[1::stride], pixels[2::stride])
                   if r < 150 and g > 160 and b > 160)
        if cyan > width * height // 1000:
            return cyan
        time.sleep(0.5)
    raise AssertionError('Heaps title did not render visible cyan graphics')


def tap(x, y):
    # SDL's immersive SurfaceView fills the display. Fit the Heaps 360x640 viewport.
    dimensions = re.findall(r'(\d+)x(\d+)', adb('shell', 'wm', 'size'))[-1]
    width, height = map(int, dimensions)
    scale = min(width / 360, height / 640)
    sx = round((width - 360 * scale) / 2 + x * scale)
    sy = round((height - 640 * scale) / 2 + y * scale)
    adb('shell', 'input', 'tap', str(sx), str(sy))


def launch():
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.GameActivity')


try:
    adb('wait-for-device')
    adb('install', '-r', str(ROOT / 'dist/neon-drift-debug.apk'))
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('logcat', '-c')
    adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    launch()
    title = wait_phase({'title'})
    time.sleep(1)
    visible_title_pixels = verify_title_rendering()
    screenshot('01-title')
    tap(180, 477)
    wait_phase({'playing'})
    time.sleep(2)
    screenshot('02-playing')
    tap(314, 43)
    paused = wait_phase({'paused'})
    screenshot('03-paused')
    adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
    time.sleep(3)
    launch()
    time.sleep(2)
    resumed = last_state()
    assert resumed == paused, ('Paused state changed in background', paused, resumed)
    tap(180, 395)
    fresh_resume = wait_phase({'playing'})
    assert fresh_resume['remaining'] == paused['remaining'], ('Background advanced timer', paused, fresh_resume)
    # Exercise both movement limits; captured images can confirm ship bounds visually.
    tap(0, 548)
    time.sleep(0.5)
    screenshot('04-left-edge')
    tap(359, 548)
    time.sleep(0.7)
    screenshot('05-right-edge')
    # Leave the ship in a lane: normal gameplay will reach a loss or 45-second win.
    terminal = wait_phase({'won', 'lost'}, seconds=55)
    screenshot('06-result')
    saved = adb('shell', 'run-as', PACKAGE, 'cat', 'files/neon-drift-best.sav')
    assert int(terminal['best']) > 0, terminal
    assert saved.strip(), 'Best score save is empty'
    tap(180, 461)
    restarted = wait_phase({'playing'})
    assert restarted['score'] == '0' and restarted['remaining'] == '45', restarted
    screenshot('07-restarted')
    # Verify automatic focus-loss pause separately from a manually paused run.
    adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
    auto_paused = wait_phase({'paused'})
    time.sleep(3)
    launch()
    time.sleep(1)
    assert last_state() == auto_paused, 'Automatic pause advanced in background'
    screenshot('08-auto-paused')
    tap(180, 395)
    fresh_auto_resume = wait_phase({'playing'})
    assert fresh_auto_resume['remaining'] == auto_paused['remaining'], ('Automatic pause advanced timer', auto_paused, fresh_auto_resume)
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('logcat', '-c')
    launch()
    reloaded = wait_phase({'title'})
    assert reloaded['best'] == terminal['best'], (terminal, reloaded)
    assert adb('shell', 'run-as', PACKAGE, 'cat', 'files/neon-drift-best.sav') == saved
    screenshot('09-best-reloaded')
    log = logs()
    assert 'Fatal signal' not in log and 'FATAL EXCEPTION' not in log, log
    report = {'visible_title_pixels': visible_title_pixels, 'title': title, 'manual_pause': paused, 'result': terminal,
              'restart': restarted, 'automatic_pause': auto_paused, 'manual_resume': fresh_resume,
              'automatic_resume': fresh_auto_resume, 'reloaded': reloaded,
              'device': adb('shell', 'getprop', 'ro.product.cpu.abi').strip()}
    (OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    (OUT / 'logcat.txt').write_text(log)
    print('PASS emulator: title, touch play, pause/background, edge steering, result, restart, automatic pause, persisted best', flush=True)
except Exception:
    (OUT / 'failure-logcat.txt').write_text(logs())
    screenshot('failure')
    raise
