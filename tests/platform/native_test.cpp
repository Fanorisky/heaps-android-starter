#include "platform_state.h"
#include "utf8_packet.h"
#include "SDL_heaps_utf16.h"
#include <cassert>
#include <cstring>
#include <thread>
#include <iostream>
static void commit(const unsigned char *s, size_t n, const uint32_t *want, size_t count) {
 size_t p=0, i=0; uint32_t packed;
 while(heaps_utf8_next(s,n,&p,&packed)) { assert(i<count); assert(packed==want[i++]); }
 assert(i==count);
}
int main() {
 const uint16_t pasted[]={0x70,0x61,0x73,0x74,0x65,0x64,0x20,0xe9,0x4e2d,0xd83d,0xde00};
 char encoded[40];size_t encodedLength=0;
 assert(SDL_HeapsUTF16ToUTF8(pasted,11,encoded,sizeof(encoded),&encodedLength));
 const unsigned char encodedWant[]={0x70,0x61,0x73,0x74,0x65,0x64,0x20,0xc3,0xa9,0xe4,0xb8,0xad,0xf0,0x9f,0x98,0x80,0};
 assert(encodedLength==16 && memcmp(encoded,encodedWant,17)==0);
 const uint32_t ingressWant[]={0x70,0x61,0x73,0x74,0x65,0x64,0x20,0xa9c3,0xadb8e4,0x80989ff0};
 commit((const unsigned char*)encoded,encodedLength,ingressWant,10);
 const uint16_t loneSurrogates[]={0xd83d,0x41,0xde00};
 assert(SDL_HeapsUTF16ToUTF8(loneSurrogates,3,encoded,sizeof(encoded),&encodedLength));
 const unsigned char loneWant[]={0xef,0xbf,0xbd,0x41,0xef,0xbf,0xbd,0};
 assert(encodedLength==7 && memcmp(encoded,loneWant,8)==0);
 assert(!SDL_HeapsUTF16ToUTF8(pasted,11,encoded,4,&encodedLength));
 heaps_text_buffer pending={};
 uint64_t beforePoll=pending.generation;
 heaps_text_cancel(&pending);
 assert(!heaps_text_install(&pending,"stale",5,17,beforePoll));
 uint32_t scalar;
 assert(!heaps_text_pop(&pending,&scalar));
 assert(heaps_text_install(&pending,"fresh",5,17,pending.generation));
 assert(heaps_text_pop(&pending,&scalar) && scalar==0x66 && pending.window==17);
 heaps_text_cancel(&pending);assert(!heaps_text_pop(&pending,&scalar));
 const uint32_t ascii[] = {0x70,0x61,0x73,0x74,0x65,0x64};
 commit((const unsigned char*)"pasted",6,ascii,6);
 const uint32_t mixed[] = {0x41,0xA9C3,0xADB8E4,0x80989FF0,0x5A};
 const unsigned char text[]={0x41,0xc3,0xa9,0xe4,0xb8,0xad,0xf0,0x9f,0x98,0x80,0x5a};
 commit(text,sizeof(text),mixed,5);
 const uint32_t invalid[] = {0xBDBFEF,0x28,0xBDBFEF,0xBDBFEF};
 const unsigned char broken[]={0xe2,0x28,0xa1,0xf0,0x9f};
 commit(broken,sizeof(broken),invalid,4);
 const uint32_t invalidScalar[] = {0xBDBFEF,0xBDBFEF,0xBDBFEF};
 const unsigned char invalidBytes[]={0xc0,0xaf,0xed,0xa0,0x80,0xf4,0x90,0x80,0x80};
 commit(invalidBytes,sizeof(invalidBytes),invalidScalar,3);
 heapsandroid::PlatformState overflow;
 overflow.setForeground(true);
 for(int i=0;i<1000;i++) overflow.setFocused((i&1)==0);
 assert(overflow.poll()==0); // Focus churn must not lose the latest foreground transition.
 heapsandroid::PlatformState state;
 state.setForeground(true); state.setForeground(true); state.setFocused(true);
 assert(state.poll()==0); assert(state.poll()==2); assert(state.poll()==-1);
 assert(state.sensorEnable(0,true)); assert(!state.sensorEnable(1,false));
 state.sensorActive(0,true); state.publishSensor(0,1.5,-2.25,0.125,0x1234567889abcdefLL);
 unsigned char packet[32]; assert(state.readSensor(0,packet));
 double x,y,z; int64_t timestamp;
 memcpy(&x,packet,8); memcpy(&y,packet+8,8); memcpy(&z,packet+16,8); memcpy(&timestamp,packet+24,8);
 assert(x==1.5 && y==-2.25 && z==0.125 && timestamp==0x1234567889abcdefLL);
 state.setForeground(false); assert(!state.readSensor(0,packet)); assert(state.sensorRequested(0));
 state.setForeground(true); state.sensorActive(0,true); assert(!state.readSensor(0,packet));
 state.publishSensor(0,9,9,9,9); assert(state.readSensor(0,packet));
 state.sensorDisable(0); assert(!state.sensorRequested(0)); assert(!state.readSensor(0,packet));
 state.setDisplay(false,false); assert(!state.immersive() && !state.keepAwake());
 state.setDisplay(true,true); assert(state.immersive() && state.keepAwake());
 for(int i=0;i<10000;i++) state.setFocused((i&1)==0);
 int events=0,last=-1,lastSeen=-1; while((last=state.poll())!=-1) {lastSeen=last;events++;assert(events<=32);}
 assert(events==32 && lastSeen==3);
 // Complete samples remain coherent while Android sensor callback publishes concurrently.
 state.sensorEnable(0,true); state.sensorActive(0,true);
 state.publishSensor(0,3,3,3,3); assert(state.readSensor(0,packet));
 state.sensorActive(0,true); assert(state.readSensor(0,packet)); // Repeated enable preserves latest complete sample.
 state.sensorDisable(0); state.sensorEnable(0,true); state.sensorActive(0,true);
 assert(!state.readSensor(0,packet));
 std::thread writer([&] {for(int i=1;i<=20000;i++) state.publishSensor(0,i,i,i,i);});
 for(int i=0;i<20000;i++) if(state.readSensor(0,packet)) {memcpy(&x,packet,8);memcpy(&y,packet+8,8);memcpy(&z,packet+16,8);memcpy(&timestamp,packet+24,8);assert(x==y&&y==z&&z==timestamp);}
 writer.join(); std::cout << "Platform native checks passed\n";
}
