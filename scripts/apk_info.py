#!/usr/bin/env python3
"""Discover application identity from the built APK, independent of template defaults."""
from pathlib import Path
import os
import re
import subprocess

SDK = Path(os.environ.get('ANDROID_HOME', '/opt/android-sdk'))
def apk_info(apk):
    text = subprocess.check_output([str(SDK / 'build-tools/34.0.0/aapt'), 'dump', 'badging', str(apk)], text=True)
    package = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", text)
    activity = re.search(r"launchable-activity: name='([^']+)'", text)
    abi = re.search(r'native-code:(.*)', text)
    minimum = re.search(r"sdkVersion:'(\d+)'", text)
    label = re.search(r"application-label:'([^']*)'", text)
    if not package or not activity or not abi or not minimum:
        raise RuntimeError('APK is missing launchable application/native metadata')
    return {'package': package[1], 'versionCode': int(package[2]), 'versionName': package[3],
            'activity': activity[1], 'abis': re.findall(r"'([^']+)'", abi[1]),
            'minSdk': int(minimum[1]), 'label': label[1] if label else ''}
