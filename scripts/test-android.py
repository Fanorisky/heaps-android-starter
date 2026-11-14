#!/usr/bin/env python3
"""Exercise the developer proof APK using its actual Android metadata."""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import time
from apk_info import apk_info

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('apk',nargs='?',default=str(ROOT/'dist/heaps-android-proof.apk'))
parser.add_argument('serial',nargs='?',default=os.environ.get('ANDROID_SERIAL'))
parser.add_argument('--audio-only',action='store_true')
args=parser.parse_args();info=apk_info(args.apk);package=info['package']
ADB=[str(Path(os.environ.get('ANDROID_HOME','/opt/android-sdk'))/'platform-tools/adb')]
if args.serial:ADB+=['-s',args.serial]
OUT=ROOT/'dist/verification';OUT.mkdir(parents=True,exist_ok=True)
controls=json.loads((ROOT/'tests/demo/features-controls.json').read_text())['centers']
def adb(*arguments,binary=False):return subprocess.check_output(ADB+list(arguments),text=not binary,timeout=30)
def logs():return adb('logcat','-d','-v','brief','hl:D','HeapsAndroid:D','AndroidRuntime:E','libc:F','*:S')
def wait_for(pattern,seconds=20):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  value=logs()
  if 'Fatal signal' in value or 'FATAL EXCEPTION' in value or 'engine error:' in value or 'RELIABILITY_TEST_FAIL' in value or 'AUDIO_TEST_FAIL' in value:raise AssertionError(value)
  found=re.search(pattern,value)
  if found:return found.group(0)
  time.sleep(.3)
 raise AssertionError('Missing log: '+pattern+'\n'+logs())
def capture(name):
 (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p',binary=True))
def launch():return adb('shell','am','start','-n',package+'/'+info['activity'])
def tap(name):
 x,y=controls[name]
 width,height=map(int,re.findall(r'(\d+)x(\d+)',adb('shell','wm','size'))[-1])
 scale=min(width/360,height/640)
 adb('shell','input','tap',str(round((width-360*scale)/2+x*scale)),str(round((height-640*scale)/2+y*scale)))
try:
 adb('wait-for-device')
 boot_deadline=time.monotonic()+120
 while adb('shell','getprop','sys.boot_completed').strip()!='1':
  if time.monotonic()>=boot_deadline:raise AssertionError('Android did not finish booting')
  time.sleep(1)
 adb('install','-r',str(Path(args.apk).resolve()))
 adb('shell','am','force-stop',package);adb('logcat','-c')
 adb('shell','input','keyevent','KEYCODE_WAKEUP');launch()
 wait_for(r'GameBase: ready');time.sleep(1);capture('gamebase-foundation')
 tap('titleFeatures');time.sleep(.5);capture('sdk-features')
 tap('audioChecks')
 result=wait_for(r'AUDIO_TEST_(?:PASS|FAIL)[^\n]+',seconds=30)
 assert result.startswith('AUDIO_TEST_PASS'),result
 capture('sdk-audio-checks')
 if not args.audio_only:
  tap('reliabilityChecks')
  for cycle in range(10):
   wait_for('RELIABILITY_READY cycle='+str(cycle),seconds=25)
   before=len(re.findall(r'HEAPS_BACKGROUND epoch=',logs()))
   adb('shell','input','keyevent','KEYCODE_HOME');time.sleep(1)
   background=re.findall(r'HEAPS_BACKGROUND epoch=(\d+) audio=(\d+) lifecycle=(\d+) sensors=(\d+) text=(\d+)',logs())
   assert len(background)>before,'Missing independent background snapshot'
   epoch,audio,lifecycle,sensors,text=map(int,background[-1])
   assert audio!=2 and lifecycle&1==0 and sensors==0 and text==0,background[-1]
   launch();time.sleep(.5)
  stress=wait_for(r'RELIABILITY_TEST_(?:PASS|FAIL)[^\n]+',seconds=25)
  assert stress.startswith('RELIABILITY_TEST_PASS'),stress
  tap('musicPlay');wait_for('Looping music requested');time.sleep(.7)
  (OUT/'audioflinger-running.txt').write_text(adb('shell','dumpsys','media.audio_flinger'))
  tap('keyboardShow');time.sleep(.7)
  adb('shell','input','text','Heaps%sSDK');time.sleep(.7)
  tap('keyboardHide');time.sleep(.5)
  prefs=adb('shell','run-as',package,'cat','files/heaps-android-settings.json')
  parsed=json.loads(prefs);assert 'Heaps SDK' in prefs,parsed
  tap('accelerometerToggle');tap('gyroscopeToggle');tap('hapticsVibrate');time.sleep(.5)
  capture('sdk-platform')
  adb('shell','input','keyevent','KEYCODE_HOME');time.sleep(2)
  (OUT/'audioflinger-background.txt').write_text(adb('shell','dumpsys','media.audio_flinger'))
  launch();time.sleep(1);capture('sdk-returned-paused')
  tap('audioResume');wait_for('Audio resumed');time.sleep(.5)
  tap('featuresBack');time.sleep(.3)
  # Explicitly resume GameBase after the lifecycle stress pause.
  before_resume=logs().count('GameBase: running')
  tap('gamePauseResume')
  end=time.monotonic()+10
  while logs().count('GameBase: running')<=before_resume and time.monotonic()<end:time.sleep(.3)
  assert logs().count('GameBase: running')>before_resume,'GameBase failed to resume explicitly'
  time.sleep(1);capture('gamebase-resumed')
  adb('shell','am','force-stop',package);adb('logcat','-c');launch();wait_for('GameBase: ready')
  assert adb('shell','run-as',package,'cat','files/heaps-android-settings.json')==prefs,'Preferences changed after process restart'
 log=logs();assert 'Fatal signal' not in log and 'FATAL EXCEPTION' not in log,log
 (OUT/'sdk-logcat.txt').write_text(log)
 (OUT/'sdk-report.json').write_text(json.dumps({'application':info,'audioChecks':result,'audioOnly':args.audio_only,'stressChecks':None if args.audio_only else stress,'hardwareAbi':adb('shell','getprop','ro.product.cpu.abi').strip()},indent=2)+'\n')
 print('PASS Android proof: '+result)
except Exception:
 (OUT/'sdk-failure-logcat.txt').write_text(logs());capture('sdk-failure');raise
