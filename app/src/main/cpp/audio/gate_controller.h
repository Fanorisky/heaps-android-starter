#ifndef HEAPS_ANDROID_GATE_CONTROLLER_H
#define HEAPS_ANDROID_GATE_CONTROLLER_H
#include <mutex>

// Device callbacks run while lifetimeMutex is held, including registration and
// the final pause. Device destruction must happen after unregister returns.
class AudioGateController {
public:
    struct Operations {
        bool (*prepare)(void *);
        void (*pause)(void *);
        void (*resume)(void *);
    };
    explicit AudioGateController(Operations operations);
    int registerDevice(void *device);
    void unregisterDevice();
    void unregisterDevice(void *closingDevice);
    void setForeground(bool foreground);
    void beginFocusRequest(int generation);
    void setFocus(int generation, bool focused);
    void abandonFocus(int generation);
    void setIntent(bool intent);
    int state();
private:
    void unregisterLocked();
    void reconcile();
    Operations operations;
    std::mutex lifetimeMutex;
    void *device = nullptr;
    bool foreground = false, focused = false, intent = false, running = false;
    int generation = 0;
};
#endif
