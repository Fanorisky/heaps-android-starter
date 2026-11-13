#!/usr/bin/env python3
"""Fetch checksum-pinned upstream sources into this repository's vendor directory."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import shutil
import tarfile
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / 'vendor'

def fetch(dep):
    cache = VENDOR / '.cache' / dep['archive']
    cache.parent.mkdir(parents=True, exist_ok=True)
    if not cache.exists():
        temp = cache.with_suffix(cache.suffix + '.download')
        print('Downloading ' + dep['name'], flush=True)
        subprocess.run(['curl', '-fLsS', '--retry', '2', '--max-time', '90', dep['url'], '-o', str(temp)], check=True)
        temp.replace(cache)
    checksum = hashlib.sha256(cache.read_bytes()).hexdigest()
    if checksum != dep['sha256']:
        raise RuntimeError('Checksum mismatch for ' + dep['name'] + '; remove ' + str(cache) + ' and retry')
    destination = VENDOR / dep['name']
    marker = destination / '.source-sha256'
    if marker.exists() and marker.read_text().strip() == checksum:
        return dep['name'] + ' verified'
    staging = VENDOR / ('.extract-' + dep['name'])
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()
    if cache.suffix == '.zip':
        with zipfile.ZipFile(cache) as archive:
            for name in archive.namelist():
                if not (staging / name).resolve().is_relative_to(staging.resolve()):
                    raise RuntimeError('Unsafe archive path')
            archive.extractall(staging)
    else:
        with tarfile.open(cache) as archive:
            archive.extractall(staging, filter='data')
    entries = list(staging.iterdir())
    source = entries[0] if len(entries) == 1 and entries[0].is_dir() else staging
    if destination.exists():
        shutil.rmtree(destination)
    shutil.move(str(source), destination)
    if staging.exists():
        shutil.rmtree(staging)
    marker.write_text(checksum + '\n')
    return dep['name'] + ' installed'

if __name__ == '__main__':
    dependencies = json.loads((ROOT / 'third_party/dependencies.lock.json').read_text())
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(fetch, dependencies):
            print(result, flush=True)
