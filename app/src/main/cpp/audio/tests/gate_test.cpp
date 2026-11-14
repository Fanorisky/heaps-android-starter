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
    int health = 0;
    int healthChecks = 0;
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
static int checkHealth(void *p) {
    auto &d = *static_cast<Device *>(p); assert(d.alive); ++d.healthChecks; return d.health;
}
static AudioGateController::Operations ops = {prepare, pauseDevice, resumeDevice, checkHealth};
static void activate(AudioGateController &gate) {
    gate.setSdkActive(true); gate.setForeground(true); gate.setWindowFocus(true);
}
static void grant(AudioGateController &gate, int generation) {
    gate.beginFocusRequest(generation);
    gate.setFocus(generation, true);
    gate.setIntent(true);
}

static void registration() {
    AudioGateController gate(ops);
    Device a, b;
    activate(gate);
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
    gate.setSdkActive(true); gate.setWindowFocus(true);
    gate.registerDevice(&a);
    grant(gate, 1);
    assert(!a.running); // focus and intent cannot override background
    activate(gate);
    assert(!a.running); // a denied background request cannot arm recovery
    gate.setIntent(true);
    assert(a.running);
    gate.setForeground(false);
    assert(!a.running && gate.state() == 1);
    activate(gate);
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
    activate(gate); gate.registerDevice(&a);
    grant(gate, 1);
    assert(gate.state() == 0 && !a.running && gate.error() == 5);
    assert(a.resumes == 1 && a.pauses == 2); // rollback even a partial start
    a.resumeSucceeds = true;
    activate(gate); gate.setFocus(1, true);
    assert(gate.state() == 0 && !a.running && a.resumes == 1);
    gate.setIntent(true);
    assert(gate.state() == 0 && !a.running && a.resumes == 1);
    gate.unregisterDevice(); gate.registerDevice(&a); grant(gate, 2);
    assert(gate.state() == 2 && a.running && a.resumes == 2);
}
static void unregisterWaitsForDeviceOperation() {
    AudioGateController gate({prepare, pauseDevice, blockingResume, checkHealth});
    Device a;
    activate(gate); gate.registerDevice(&a);
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
static void independentInputsAndRouteLoss() {
    AudioGateController gate(ops); Device a;
    gate.setForeground(true); gate.setWindowFocus(true); gate.registerDevice(&a);
    grant(gate, 1); assert(gate.state() == 1 && !a.running); // SDK starts stopped
    gate.setSdkActive(true); assert(gate.state() == 1);
    gate.setIntent(true); assert(gate.state() == 2);
    gate.setWindowFocus(false); assert(!a.running);
    gate.setForeground(true); gate.setIntent(true); assert(!a.running);
    gate.setWindowFocus(true); assert(!a.running); // gain cannot restore intent
    gate.setIntent(true); assert(a.running);
    gate.routeChanged(); assert(!a.running && gate.state() == 1);
    gate.setFocus(1, true); assert(!a.running);
    gate.setIntent(true); assert(a.running);
    gate.setSdkActive(false); assert(!a.running);
    gate.setSdkActive(true); assert(!a.running);
    gate.setIntent(true); assert(a.running);
}
static void lateHealthFailureLatchesUnavailable() {
    AudioGateController gate(ops); Device a; activate(gate);
    assert(gate.error() == 1); gate.registerDevice(&a); grant(gate, 1);
    assert(gate.state() == 2 && gate.error() == 0);
    a.health = 3;
    // A callback cannot probe context/device health. The Haxe-thread getter does.
    gate.setForeground(true); assert(a.running);
    assert(gate.state() == 0 && !a.running && gate.error() == 3);
    a.health = 0; grant(gate, 2); assert(gate.state() == 0 && !a.running);
    gate.unregisterDevice(); gate.registerDevice(&a); assert(gate.state() == 1 && gate.error() == 0);
    grant(gate, 3); a.health = 4;
    assert(gate.checkHealth() == 4 && gate.state() == 0 && !a.running);
}
static bool releaseHealth = false;
static int blockingHealth(void *p) {
    std::unique_lock<std::mutex> lock(blockMutex);
    entered = true; blockCondition.notify_all();
    blockCondition.wait(lock, [] { return releaseHealth; });
    return checkHealth(p);
}
static void unregisterWaitsForHealthProbe() {
    AudioGateController gate({prepare, pauseDevice, resumeDevice, blockingHealth});
    Device a; activate(gate); gate.registerDevice(&a); grant(gate, 1);
    entered = false;
    std::thread probe([&] { assert(gate.checkHealth() == 0); });
    { std::unique_lock<std::mutex> lock(blockMutex); blockCondition.wait(lock, [] { return entered; }); }
    std::atomic<bool> started{false}, returned{false};
    std::thread destroy([&] { started = true; gate.unregisterDevice(); a.alive = false; returned = true; });
    while (!started) std::this_thread::yield();
    assert(!returned);
    { std::lock_guard<std::mutex> lock(blockMutex); releaseHealth = true; }
    blockCondition.notify_all(); probe.join(); destroy.join();
    assert(returned && gate.state() == 0 && gate.error() == 1);
    assert(gate.checkHealth() == 1);
}
static void cachedPeekNeverProbesHealth() {
    AudioGateController gate(ops); Device a; activate(gate);
    assert(gate.peekState() == 0);
    gate.registerDevice(&a); grant(gate, 1);
    assert(gate.peekState() == 2 && a.healthChecks == 0);
    a.health = 3; // Callback diagnostics report only the already-known state.
    assert(gate.peekState() == 2 && a.healthChecks == 0);
    gate.setForeground(false);
    assert(gate.peekState() == 1 && !a.running && a.healthChecks == 0);
    gate.setForeground(true); gate.setIntent(true);
    gate.setWindowFocus(false);
    assert(gate.peekState() == 1 && a.healthChecks == 0);
    gate.setWindowFocus(true); gate.setIntent(true); gate.routeChanged();
    assert(gate.peekState() == 1 && a.healthChecks == 0);
    assert(gate.state() == 0 && a.healthChecks == 1);
    assert(gate.peekState() == 0 && a.healthChecks == 1);
    gate.unregisterDevice(); a.alive = false;
    assert(gate.peekState() == 0 && a.healthChecks == 1);
}
static void cachedPeekRacesLossAndUnregister() {
    AudioGateController gate(ops); Device a; activate(gate);
    gate.registerDevice(&a); grant(gate, 1);
    std::atomic<bool> enteredPeek{false}, stopped{false};
    std::thread observer([&] {
        enteredPeek = true;
        while (!stopped) {
            const int value = gate.peekState();
            assert(value >= 0 && value <= 2);
        }
        for (int i = 0; i < 1000; ++i) assert(gate.peekState() == 0);
    });
    while (!enteredPeek) std::this_thread::yield();
    gate.setForeground(false); gate.unregisterDevice();
    a.alive = false; stopped = true; observer.join();
    assert(gate.peekState() == 0 && a.healthChecks == 0);
}
int main() {
    registration(); lossRequiresExplicitResume(); failedResumeStaysPausedAndClearsIntent();
    unregisterWaitsForDeviceOperation();
    independentInputsAndRouteLoss(); lateHealthFailureLatchesUnavailable(); unregisterWaitsForHealthProbe();
    cachedPeekNeverProbesHealth(); cachedPeekRacesLossAndUnregister();
    std::cout << "AUDIO_GATE_TEST_PASS\n";
}
