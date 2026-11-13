#ifndef HEAPSANDROID_PLATFORM_STATE_H
#define HEAPSANDROID_PLATFORM_STATE_H
#include <cstdint>
#include <cstring>
#include <mutex>
namespace heapsandroid {
/** Native-only callback state. No HashLink pointers or allocation lives here. */
class PlatformState {
 mutable std::mutex lock;
 int events[32] = {}, head=0, count=0;
 bool fg=false, focus=false, displayImmersive=false, displayAwake=false;
 struct SensorSlot {bool requested=false, active=false, valid=false; uint64_t version=0; unsigned char packet[2][32]={};};
 SensorSlot sensors[2];
 void push(int event) {
  if(count && events[(head+count-1)%32]==event) return;
  if(count==32) {
   // Coalesce within the same state dimension so focus churn cannot erase
   // the latest foreground transition (and foreground churn preserves focus).
   int drop=0;while(drop<count && (events[(head+drop)%32]<2)!=(event<2))drop++;
   if(drop==count)drop=0;
   for(int i=drop;i<count-1;i++)events[(head+i)%32]=events[(head+i+1)%32];
   count--;
  }
  events[(head+count)%32]=event;count++;
 }
 public:
 void setForeground(bool value) {std::lock_guard<std::mutex> g(lock);if(fg==value)return;fg=value;push(value?0:1);if(!value) for(auto &s:sensors){s.active=false;s.valid=false;}}
 void setFocused(bool value) {std::lock_guard<std::mutex> g(lock);if(focus==value)return;focus=value;push(value?2:3);}
 int poll() {std::lock_guard<std::mutex> g(lock);if(!count)return -1;int e=events[head];head=(head+1)%32;count--;return e;}
 int lifecycleState() const {std::lock_guard<std::mutex> g(lock);return (fg?1:0)|(focus?2:0);}
 bool sensorEnable(int kind,bool available) {std::lock_guard<std::mutex> g(lock);if(kind<0||kind>1||!available)return false;sensors[kind].requested=true;return true;}
 void sensorDisable(int kind) {std::lock_guard<std::mutex> g(lock);if(kind<0||kind>1)return;auto &s=sensors[kind];s.requested=false;s.active=false;s.valid=false;}
 bool sensorRequested(int kind) const {std::lock_guard<std::mutex> g(lock);return kind>=0&&kind<2&&sensors[kind].requested;}
 void sensorActive(int kind,bool active) {std::lock_guard<std::mutex> g(lock);if(kind<0||kind>1)return;auto &s=sensors[kind];bool next=active&&s.requested&&fg;if(s.active!=next){s.active=next;s.valid=false;}}
 void publishSensor(int kind,double x,double y,double z,int64_t timestamp) {
  std::lock_guard<std::mutex> g(lock);if(kind<0||kind>1)return;auto &s=sensors[kind];if(!fg||!s.active||!s.requested)return;
  unsigned char *p=s.packet[(s.version+1)&1];memcpy(p,&x,8);memcpy(p+8,&y,8);memcpy(p+16,&z,8);memcpy(p+24,&timestamp,8);s.version++;s.valid=true;
 }
 bool readSensor(int kind,unsigned char *packet) const {std::lock_guard<std::mutex> g(lock);if(kind<0||kind>1)return false;auto &s=sensors[kind];if(!fg||!s.requested||!s.active||!s.valid)return false;memcpy(packet,s.packet[s.version&1],32);return true;}
 void setDisplay(bool immersive,bool awake) {std::lock_guard<std::mutex> g(lock);displayImmersive=immersive;displayAwake=awake;}
 bool immersive() const {std::lock_guard<std::mutex> g(lock);return displayImmersive;}
 bool keepAwake() const {std::lock_guard<std::mutex> g(lock);return displayAwake;}
 void reset() {std::lock_guard<std::mutex> g(lock);fg=focus=false;head=count=0;for(auto &s:sensors)s=SensorSlot();}
};
}
#endif
