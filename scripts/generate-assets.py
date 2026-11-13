#!/usr/bin/env python3
"""Original deterministic CC0 demo resources; no third-party media inputs."""
import argparse, hashlib, io, json, math, pathlib, struct, wave, zlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets'
RATE=22050

def png():
    def chunk(kind,data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    pixels=bytearray()
    for y in range(32):
        pixels.append(0)
        for x in range(32):
            ship=(5<=y<=26 and abs(x-15.5)<=(y-3)*0.48)
            core=abs(x-15.5)<2 and 12<=y<=21
            edge=ship and (abs(x-15.5)>(y-3)*0.48-2 or y<=7 or y>=25)
            pixels.extend((228,244,255,255) if core else (101,237,255,255) if edge else (22,71,92,255) if ship else (0,0,0,0))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',32,32,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(pixels),9))+chunk(b'IEND',b'')

def sound(notes,duration,loop=False):
    frames=int(RATE*duration)
    pcm=[]
    for i in range(frames):
        t=i/RATE
        section=min(len(notes)-1,int(t/duration*len(notes)))
        phase=t*notes[section]
        envelope=0.32 if loop else 0.5*min(1,t/0.012)*max(0,1-t/duration)**2
        # A continuous fixed bass cycle makes the music boundary seamless.
        if loop:
            value=(math.sin(2*math.pi*110*t)+0.35*math.sin(2*math.pi*220*t)+0.15*math.sin(2*math.pi*330*t))*envelope
        else: value=(math.sin(2*math.pi*phase)+0.2*math.sin(4*math.pi*phase))*envelope
        pcm.append(round(max(-0.85,min(0.85,value))*32767))
    output=io.BytesIO()
    with wave.open(output,'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(struct.pack('<'+'h'*frames,*pcm))
    return output.getvalue()

def outputs():
    assets={'ship.png':png()}
    specs={'ui':([660,880],0.08),'start':([330,440,660],0.3),'pickup':([880,1320],0.16),'hit':([165,82.5],0.22),'win':([440,550,660,880],0.65),'lose':([330,220,165,110],0.6)}
    for name,(notes,duration) in specs.items(): assets[name+'.wav']=sound(notes,duration)
    assets['music.wav']=sound([110],4.,True)
    manifest={'author':'Heaps Android Starter contributors (generated with Codex)','license':'CC0-1.0','description':'Original procedural neon ship and sine-wave audio generated without external media.','sampleRate':RATE,'sha256':{n:hashlib.sha256(v).hexdigest() for n,v in sorted(assets.items())}}
    assets['manifest.json']=(json.dumps(manifest,indent=2,sort_keys=True)+'\n').encode()
    assets['LICENSE.txt']=b'Original demo media by Heaps Android Starter contributors.\nDedicated to the public domain under CC0 1.0 Universal.\nhttps://creativecommons.org/publicdomain/zero/1.0/\nNo third-party artwork or recordings were used.\n'
    return assets

def validate(name,data):
    if name.endswith('.wav'):
        with wave.open(io.BytesIO(data),'rb') as w:
            assert (w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,RATE)
            samples=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
            assert samples and 0<max(abs(v) for v in samples)<=27852
    elif name.endswith('.png'):
        assert data[:8]==b'\x89PNG\r\n\x1a\n'
        pos=8; compressed=b''
        while pos<len(data):
            size=struct.unpack('>I',data[pos:pos+4])[0]; kind=data[pos+4:pos+8]; payload=data[pos+8:pos+8+size]
            assert zlib.crc32(kind+payload)&0xffffffff==struct.unpack('>I',data[pos+8+size:pos+12+size])[0]
            if kind==b'IHDR': assert struct.unpack('>IIBBBBB',payload)==(32,32,8,6,0,0,0)
            if kind==b'IDAT': compressed+=payload
            pos+=size+12
        assert len(zlib.decompress(compressed))==32*(1+32*4)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    ASSETS.mkdir(exist_ok=True)
    for name,data in outputs().items():
        validate(name,data);path=ASSETS/name
        if args.check:
            if not path.exists() or path.read_bytes()!=data: raise SystemExit('Asset mismatch: '+name)
        else: path.write_bytes(data)
    print('Assets: original PNG and 7 PCM16 WAV resources validated'+(' and reproduced byte-for-byte' if args.check else ''))
if __name__=='__main__': main()
