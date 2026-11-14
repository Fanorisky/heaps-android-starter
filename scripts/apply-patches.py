#!/usr/bin/env python3
"""Apply checked local patches to a pinned extraction, or validate their applied state."""
from pathlib import Path
import argparse
import subprocess

ROOT=Path(__file__).resolve().parents[1]
def apply_all(vendor:Path,patches:Path)->None:
    vendor=vendor.resolve();patches=patches.resolve()
    if not vendor.is_dir() or not patches.is_dir():
        raise RuntimeError('Vendor and patch directories must exist')
    for patch in sorted(patches.glob('*.patch')):
        command=['git','-C',str(vendor),'apply']
        forward=subprocess.run(command+['--check',str(patch)],capture_output=True)
        if forward.returncode==0:
            subprocess.run(command+[str(patch)],check=True,capture_output=True)
        else:
            reverse=subprocess.run(command+['--reverse','--check',str(patch)],capture_output=True)
            if reverse.returncode!=0:
                raise RuntimeError('Patch neither applicable nor already applied: '+patch.name+'\n'+forward.stderr.decode())
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--vendor',type=Path,default=ROOT/'vendor')
    parser.add_argument('--patches',type=Path,default=ROOT/'patches')
    args=parser.parse_args()
    apply_all(args.vendor,args.patches)
