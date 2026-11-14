#ifndef HEAPSANDROID_SESSION_EPOCH_H
#define HEAPSANDROID_SESSION_EPOCH_H
#include <cstdint>
#include <mutex>
namespace heapsandroid {
/** Second callback boundary. Validation and effects are inseparable under this mutex. */
class SessionEpoch {
 std::mutex mutex;
 int64_t active=0, latest=0;
 public:
 template<class F> bool start(int64_t epoch,F publish) {
  std::lock_guard<std::mutex> guard(mutex);
  if(epoch<=latest || active!=0)return false;
  active=latest=epoch;publish();return true;
 }
 template<class F> bool run(int64_t epoch,F publish) {
  std::lock_guard<std::mutex> guard(mutex);
  if(epoch<=0 || epoch!=active)return false;
  publish();return true;
 }
 template<class F> bool stop(int64_t epoch,F publish) {
  std::lock_guard<std::mutex> guard(mutex);
  if(epoch<=0 || epoch!=active)return false;
  publish();active=0;return true;
 }
};
}
#endif
