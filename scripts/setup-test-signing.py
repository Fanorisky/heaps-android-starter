#!/usr/bin/env python3
"""Create/reuse a private development keystore and optionally configure CI secrets."""
from pathlib import Path
import argparse
import base64
import json
import os
import re
import secrets
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--github-repo', help='Upload this dedicated test identity to repository Actions secrets')
args = parser.parse_args()
folder = ROOT / 'signing'
folder.mkdir(mode=0o700, exist_ok=True)
folder.chmod(0o700)
key = folder / 'test.keystore'
properties = folder / 'test.properties'
password_file = folder / 'store-password'
if key.exists() != properties.exists():
    raise SystemExit('Incomplete signing identity; recover its backup instead of replacing it')
if not key.exists():
    password = secrets.token_urlsafe(32)
    password_file.write_text(password + '\n')
    password_file.chmod(0o600)
    alias = 'heapsandroid-test'
    subprocess.run(['keytool', '-genkeypair', '-keystore', str(key), '-storetype', 'PKCS12',
                    '-alias', alias, '-keyalg', 'RSA', '-keysize', '3072', '-validity', '3650',
                    '-dname', 'CN=Heaps Android Test, O=Heaps Android Contributors',
                    '-storepass:file', str(password_file), '-keypass:file', str(password_file)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    properties.write_text('storePassword=' + password + '\nkeyPassword=' + password + '\nkeyAlias=' + alias + '\n')
    properties.chmod(0o600)
    key.chmod(0o600)
else:
    values = dict(line.split('=', 1) for line in properties.read_text().splitlines() if '=' in line)
    password = values['storePassword']
    alias = values['keyAlias']
    password_file.write_text(password + '\n')
    password_file.chmod(0o600)
values = dict(line.split('=', 1) for line in properties.read_text().splitlines() if '=' in line)
listing = subprocess.check_output(['keytool', '-list', '-v', '-keystore', str(key), '-alias', alias,
                                  '-storepass:file', str(password_file), '-J-Duser.language=en'], text=True)
fingerprint = re.search(r'SHA256:\s*([0-9A-F:]+)', listing).group(1).replace(':', '').lower()
backup = Path.home() / '.local/share/heapsandroid-signing' / fingerprint[:16]
backup.mkdir(mode=0o700, parents=True, exist_ok=True)
backup.chmod(0o700)
for source in (key, properties):
    destination = backup / source.name
    if destination.exists() and destination.read_bytes() != source.read_bytes():
        raise SystemExit('Signing backup collision; refusing to overwrite')
    shutil.copyfile(source, destination)
    destination.chmod(0o600)
public = ROOT / 'docs/signing'
public.mkdir(parents=True, exist_ok=True)
(public / 'test-certificate-sha256.txt').write_text(fingerprint + '\n')
if args.github_repo:
    secrets_by_name = {
        'HEAPS_ANDROID_TEST_KEYSTORE': base64.b64encode(key.read_bytes()),
        'HEAPS_ANDROID_TEST_STORE_PASSWORD': values['storePassword'].encode(),
        'HEAPS_ANDROID_TEST_KEY_PASSWORD': values['keyPassword'].encode(),
        'HEAPS_ANDROID_TEST_KEY_ALIAS': values['keyAlias'].encode(),
    }
    for name, value in secrets_by_name.items():
        subprocess.run(['gh', 'secret', 'set', name, '--repo', args.github_repo], input=value,
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    print('Configured dedicated repository test-signing secrets')
print('Public test certificate SHA-256: ' + fingerprint)
print('Private signing backup: ' + str(backup))
