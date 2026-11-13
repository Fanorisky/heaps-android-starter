#!/usr/bin/env python3
"""Apply explicit upstream compatibility patches once per clean extraction."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[1]
for patch in sorted((ROOT / 'patches').glob('*.patch')):
    forward = subprocess.run(['git', 'apply', '--check', str(patch)], cwd=ROOT / 'vendor', capture_output=True)
    if forward.returncode == 0:
        subprocess.run(['git', 'apply', str(patch)], cwd=ROOT / 'vendor', check=True)
    else:
        reverse = subprocess.run(['git', 'apply', '--reverse', '--check', str(patch)], cwd=ROOT / 'vendor', capture_output=True)
        if reverse.returncode != 0:
            raise RuntimeError('Patch neither applicable nor already applied: ' + patch.name + '\n' + forward.stderr.decode())
