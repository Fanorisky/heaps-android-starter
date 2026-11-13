#include "../gate_controller.h"
#include <atomic>
#include <cassert>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <thread>

// Only the physical device operations are substituted; the gate and lifetime
// synchronization exercised here are the production controller.
struct Device {
    bool alive = true;
    bool running = false;
    int pauses = 0;
    int resumes = 0;
    bool supported = true;
    bool resumeSucceeds = true;
};
static bool prepare(void *p) { return static_cast<Device *>(p)->supported; }
static void pauseDevice(void *p) {
    auto &d = *static_cast<Device *>(p);
    assert(d.alive); d.running = false; ++d.pauses;
}
static bool resumeDevice(void *p) {
    auto &d = *static_cast<Device *>(p);
    assert(d.alive); d.running = true; ++d.resumes;
    return d.resumeSucceeds;
}
static AudioGateController::Operations ops = {prepare, pauseDevice, resumeDevice};
static void grant(AudioGateController &gate, int generation) {
    gate.beginFocusRequest(generation);
    gate.setFocus(generation, true);
    gate.setIntent(true);
}

static void registration() {
    AudioGateController gate(ops);
    Device a, b;
    gate.setForeground(true);
    assert(gate.registerDevice(nullptr) == 0);
    b.supported = false;
    assert(gate.registerDevice(&b) == 0);
    assert(gate.state() == 0);
    assert(gate.registerDevice(&a) == 1);
    assert(!a.running && a.pauses == 1 && gate.state() == 1);
    grant(gate, 1);
    assert(a.running && gate.state() == 2);
    assert(gate.registerDevice(&a) == 1);
    assert(a.running && a.pauses == 1);
    assert(gate.registerDevice(&b) == 0);
    gate.unregisterDevice(&b);
    assert(a.running && gate.state() == 2); // closing another device is harmless
    gate.unregisterDevice(nullptr);
    assert(a.running);
    gate.unregisterDevice();
    assert(!a.running && gate.state() == 0);
    gate.setFocus(1, true); gate.setIntent(true);
    assert(gate.state() == 0);
    auto count = a.pauses;
    gate.unregisterDevice();
    assert(a.pauses == count);
    assert(gate.registerDevice(&a) == 1);
    gate.setFocus(1, true);
    gate.setIntent(true);
    assert(gate.state() == 1); // old generation invalid after registration
}
static void lossRequiresExplicitResume() {
    AudioGateController gate(ops);
    Device a;
    gate.registerDevice(&a);
    grant(gate, 1);
    assert(!a.running); // focus and intent cannot override background
    gate.setForeground(true);
    assert(!a.running); // a denied background request cannot arm recovery
    gate.setIntent(true);
    assert(a.running);
    gate.setForeground(false);
    assert(!a.running && gate.state() == 1);
    gate.setForeground(true);
    assert(!a.running); // background clears playback intent
    gate.setIntent(true);
    assert(a.running);
    gate.setFocus(1, false);
    assert(!a.running);
    gate.setFocus(1, true);
    assert(!a.running); // focus recovery clears no prior loss
    gate.setIntent(true);
    assert(a.running);
    gate.beginFocusRequest(2);
    assert(!a.running);
    gate.setFocus(1, true);
    gate.abandonFocus(1);
    gate.setIntent(true);
    assert(!a.running); // stale gain cannot grant focus
    gate.setFocus(2, true);
    assert(!a.running); // denied intent cannot arm delayed gain
    gate.setIntent(true);
    assert(a.running);
    gate.abandonFocus(1);
    assert(a.running); // stale abandon cannot revoke a newer grant
    gate.abandonFocus(2);
    assert(!a.running);
    gate.setFocus(2, true);
    gate.setIntent(true);
    assert(!a.running); // abandoned generation stays invalid
    gate.beginFocusRequest(0);
    gate.setFocus(0, true);
    assert(!a.running);
}
static std::mutex blockMutex;
static std::condition_variable blockCondition;
static bool entered = false, releaseResume = false;
static bool blockingResume(void *p) {
    std::unique_lock<std::mutex> lock(blockMutex);
    entered = true; blockCondition.notify_all();
    blockCondition.wait(lock, [] { return releaseResume; });
    return resumeDevice(p);
}
static void failedResumeStaysPausedAndClearsIntent() {
    AudioGateController gate(ops);
    Device a;
    a.resumeSucceeds = false;
    gate.setForeground(true); gate.registerDevice(&a);
    grant(gate, 1);
    assert(gate.state() == 1 && !a.running);
    assert(a.resumes == 1 && a.pauses == 2); // rollback even a partial start
    a.resumeSucceeds = true;
    gate.setForeground(true); gate.setFocus(1, true);
    assert(gate.state() == 1 && !a.running && a.resumes == 1);
    gate.setIntent(true); // only a fresh explicit request may retry
    assert(gate.state() == 2 && a.running && a.resumes == 2);
}
static void unregisterWaitsForDeviceOperation() {
    AudioGateController gate({prepare, pauseDevice, blockingResume});
    Device a;
    gate.setForeground(true); gate.registerDevice(&a);
    gate.beginFocusRequest(1); gate.setFocus(1, true);
    std::thread callback([&] { gate.setIntent(true); });
    { std::unique_lock<std::mutex> lock(blockMutex);
      blockCondition.wait(lock, [] { return entered; }); }
    std::atomic<bool> started{false}, returned{false};
    std::thread destroy([&] {
        started = true;
        gate.unregisterDevice();
        a.alive = false; returned = true;
    });
    while (!started) std::this_thread::yield();
    assert(!returned);
    { std::lock_guard<std::mutex> lock(blockMutex); releaseResume = true; }
    blockCondition.notify_all();
    callback.join(); destroy.join();
    assert(returned && !a.running && gate.state() == 0);
    // Java callbacks arriving after actual destruction cannot touch the device.
    for (int i = 0; i < 10000; ++i) {
        gate.setFocus(1, true); gate.setForeground(i % 2); gate.setIntent(true);
    }
    assert(gate.state() == 0);
}
int main() {
    registration(); lossRequiresExplicitResume(); failedResumeStaysPausedAndClearsIntent();
    unregisterWaitsForDeviceOperation();
    std::cout << "AUDIO_GATE_TEST_PASS\n";
}
