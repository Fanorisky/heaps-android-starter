#include "gate_controller.h"
#include "../include/audio_gate.h"

AudioGateController::AudioGateController(Operations operations) : operations(operations) {}
int AudioGateController::registerDevice(void *value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (!value) { if (!device) lastError = AUDIO_ERROR_NO_DEVICE; return 0; }
    if (device) return device == value && lastError == AUDIO_ERROR_NONE ? 1 : 0;
    if (!operations.prepare(value)) { lastError = AUDIO_ERROR_UNSUPPORTED; return 0; }
    device = value;
    lastError = AUDIO_ERROR_NONE;
    focused = intent = running = false;
    generation = 0;
    operations.pause(device);
    return 1;
}
void AudioGateController::unregisterDevice() {
    std::lock_guard<std::mutex> lock(lifetimeMutex); unregisterLocked();
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
    lastError = AUDIO_ERROR_NO_DEVICE;
}
void AudioGateController::failLocked(int error) {
    if (device) operations.pause(device);
    intent = running = false;
    lastError = error;
}
int AudioGateController::healthLocked() {
    if (device && lastError == AUDIO_ERROR_NONE) {
        int error = operations.checkHealth(device);
        if (error != AUDIO_ERROR_NONE) failLocked(error);
    }
    return lastError;
}
void AudioGateController::reconcile() {
    bool next = device && lastError == AUDIO_ERROR_NONE && sdkActive && foreground && windowFocused && focused && intent;
    if (device && next != running) {
        if (next) {
            if (!operations.resume(device)) {
                // A partially started backend is paused and unavailable until
                // its device has actually been destroyed and recreated.
                failLocked(AUDIO_ERROR_RESUME_FAILURE);
                return;
            }
        } else operations.pause(device);
    }
    running = next;
}
void AudioGateController::setSdkActive(bool value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    sdkActive = value; if (!value) intent = false; reconcile();
}
void AudioGateController::setForeground(bool value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    foreground = value; if (!value) intent = false; reconcile();
}
void AudioGateController::setWindowFocus(bool value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    windowFocused = value; if (!value) intent = false; reconcile();
}
void AudioGateController::routeChanged() {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    intent = false; reconcile();
}
void AudioGateController::beginFocusRequest(int value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (!device || value <= 0) return;
    generation = value; focused = intent = false; reconcile();
}
void AudioGateController::setFocus(int value, bool focus) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (!device || value <= 0 || value != generation) return;
    focused = focus; if (!focus) intent = false; reconcile();
}
void AudioGateController::abandonFocus(int value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    if (!device || value <= 0 || value != generation) return;
    generation = 0; focused = intent = false; reconcile();
}
void AudioGateController::setIntent(bool value) {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    intent = value && device && lastError == AUDIO_ERROR_NONE && sdkActive && foreground && windowFocused && focused;
    reconcile();
}
int AudioGateController::state() {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    healthLocked();
    return !device || lastError != AUDIO_ERROR_NONE ? AUDIO_GATE_UNREGISTERED : running ? AUDIO_GATE_RUNNING : AUDIO_GATE_PAUSED;
}
int AudioGateController::peekState() {
    std::lock_guard<std::mutex> lock(lifetimeMutex);
    return !device || lastError != AUDIO_ERROR_NONE ? AUDIO_GATE_UNREGISTERED : running ? AUDIO_GATE_RUNNING : AUDIO_GATE_PAUSED;
}
int AudioGateController::error() {
    std::lock_guard<std::mutex> lock(lifetimeMutex); return healthLocked();
}
int AudioGateController::checkHealth() {
    std::lock_guard<std::mutex> lock(lifetimeMutex); return healthLocked();
}
