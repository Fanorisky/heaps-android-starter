#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
./gradlew :app:assembleDebug -PandroidReliabilityFixtures=true -PandroidAbis=x86_64 -Papp.application_id=io.heaps.android.brokenfixture "$@"
"$ANDROID_HOME/platform-tools/adb" install -r app/build/outputs/apk/debug/app-debug.apk
"$ANDROID_HOME/platform-tools/adb" logcat -c
"$ANDROID_HOME/platform-tools/adb" shell am start -n io.heaps.android.brokenfixture/io.heaps.android.BrokenLibrariesActivity
python3 - <<'PY'
import os,subprocess,time
adb=os.environ['ANDROID_HOME']+'/platform-tools/adb'
time.sleep(2)
log=subprocess.check_output([adb,'logcat','-d','-v','brief'],text=True)
assert 'heaps_missing_test_library' in log, 'Missing library fixture did not reach load failure'
assert 'FATAL EXCEPTION' not in log and 'Fatal signal' not in log, log
assert subprocess.check_output([adb,'shell','pidof','io.heaps.android.brokenfixture'],text=True).strip(), 'Error host exited'
subprocess.run([adb,'shell','am','force-stop','io.heaps.android.brokenfixture'],check=True)
log=subprocess.check_output([adb,'logcat','-d','-v','brief'],text=True)
assert 'FATAL EXCEPTION' not in log and 'Fatal signal' not in log,log
print('PASS broken-library Android host: error path stays alive, no JNI lifecycle crash')
PY
