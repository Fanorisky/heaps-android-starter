#include "gate_controller.h"

AudioGateController::AudioGateController(Operations operations) : operations(operations) {}
int AudioGateController::registerDevice(void *value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (!value) return 0;
    if (device) return device == value ? 1 : 0;
    if (!operations.prepare(value)) return 0;
    device = value;
    focused = intent = running = false;
    generation = 0;
    operations.pause(device);
    return 1;
}
void AudioGateController::unregisterDevice() {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    unregisterLocked();
}
void AudioGateController::unregisterDevice(void *closingDevice) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (closingDevice && closingDevice == device) unregisterLocked();
}
void AudioGateController::unregisterLocked() {
    if (device) operations.pause(device);
    device = nullptr;
    generation = 0;
    focused = intent = running = false;
}
void AudioGateController::reconcile() {
    bool next = device && foreground && focused && intent;
    if (device && next != running) {
        if (next) {
            if (!operations.resume(device)) {
                // Backends may partially start before reporting an error.
                // Restore pause and require fresh intent before retrying.
                operations.pause(device);
                intent = false;
                next = false;
            }
        } else operations.pause(device);
    }
    running = next;
}
void AudioGateController::setForeground(bool value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    foreground = value;
    if (!value) intent = false;
    reconcile();
}
void AudioGateController::beginFocusRequest(int value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (!device || value <= 0) return;
    generation = value;
    focused = intent = false;
    reconcile();
}
void AudioGateController::setFocus(int value, bool focus) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (!device || value <= 0 || value != generation) return;
    focused = focus;
    if (!focus) intent = false;
    reconcile();
}
void AudioGateController::abandonFocus(int value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (!device || value <= 0 || value != generation) return;
    generation = 0;
    focused = intent = false;
    reconcile();
}
void AudioGateController::setIntent(bool value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    // Failed or delayed requests never arm a later foreground/focus recovery.
    intent = value && device && foreground && focused;
    reconcile();
}
int AudioGateController::state() {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    return !device ? 0 : running ? 2 : 1;
}
