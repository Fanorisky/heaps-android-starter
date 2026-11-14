#!/usr/bin/env python3
"""Exercise fresh, applied, v0.2.0-upgrade and incompatible pinned patch targets."""
from pathlib import Path
import hashlib
import importlib.util
import json
import subprocess
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('patch_tool',ROOT/'scripts/apply-patches.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
LOCK=json.loads((ROOT/'third_party/dependencies.lock.json').read_text())
BASELINE='36a15d9f9310a24b03a2aed5198e27160976caac'
def extract(directory):
    directory.mkdir()
    for dep in LOCK:
        if dep['name'] not in ('heaps','hashlink','sdl'):continue
        archive=ROOT/'vendor/.cache'/dep['archive']
        if hashlib.sha256(archive.read_bytes()).hexdigest()!=dep['sha256']:
            raise RuntimeError('Pinned archive checksum mismatch: '+dep['name'])
        stage=directory/('.'+dep['name']);stage.mkdir()
        with tarfile.open(archive) as contents:contents.extractall(stage,filter='data')
        root=next(stage.iterdir());root.rename(directory/dep['name']);stage.rmdir()
def digest(directory):
    return {str(p.relative_to(directory)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in directory.rglob('*') if p.is_file()}
with tempfile.TemporaryDirectory(prefix='heaps-patch-test-') as temp:
    base=Path(temp);fresh=base/'fresh';extract(fresh)
    module.apply_all(fresh,ROOT/'patches');expected=digest(fresh)
    module.apply_all(fresh,ROOT/'patches')
    assert digest(fresh)==expected,'Second patch application changed files'
    old=base/'published-v0.2';extract(old);old_patches=base/'old-patches';old_patches.mkdir()
    files=subprocess.check_output(['git','-C',str(ROOT),'ls-tree','-r','--name-only',BASELINE,'patches'],text=True).splitlines()
    for name in files:
        if name.endswith('.patch'):
            (old_patches/Path(name).name).write_bytes(subprocess.check_output(['git','-C',str(ROOT),'show',BASELINE+':'+name]))
    module.apply_all(old,old_patches);module.apply_all(old,ROOT/'patches')
    assert digest(old)==expected,'Published-old checkout upgrade differs from clean build'
    target=fresh/'heaps/h3d/impl/GlDriver.hx';target.write_text('incompatible target revision\n')
    try:module.apply_all(fresh,ROOT/'patches')
    except RuntimeError as error:
        assert 'neither applicable nor already applied' in str(error)
    else:raise AssertionError('Incompatible target accepted')
print('PASS PATCHES: fresh pinned extraction, idempotency, v0.2.0 upgrade, incompatible rejection')
