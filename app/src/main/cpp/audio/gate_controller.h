#ifndef HEAPS_ANDROID_GATE_CONTROLLER_H
#define HEAPS_ANDROID_GATE_CONTROLLER_H
#include <mutex>

// Every operation holds lifetimeMutex. Device destruction follows unregister.
// Only state/error/checkHealth are called by the Haxe thread and probe health;
// Android callbacks publish inputs without querying any current AL context.
class AudioGateController {
public:
    struct Operations {
        bool (*prepare)(void *);
        void (*pause)(void *);
        bool (*resume)(void *);
        int (*checkHealth)(void *);
    };
    explicit AudioGateController(Operations operations);
    int registerDevice(void *device);
    void unregisterDevice();
    void unregisterDevice(void *closingDevice);
    void setSdkActive(bool active);
    void setForeground(bool foreground);
    void setWindowFocus(bool focused);
    void routeChanged();
    void beginFocusRequest(int generation);
    void setFocus(int generation, bool focused);
    void abandonFocus(int generation);
    void setIntent(bool intent);
    int state();
    // Callback-safe cached observation; never probes a device or context.
    int peekState();
    int error();
    int checkHealth();
private:
    void unregisterLocked();
    void reconcile();
    int healthLocked();
    void failLocked(int error);
    Operations operations;
    std::mutex lifetimeMutex;
    void *device = nullptr;
    bool sdkActive = false, foreground = false, windowFocused = false;
    bool focused = false, intent = false, running = false;
    int generation = 0;
    int lastError = 1;
};
#endif
