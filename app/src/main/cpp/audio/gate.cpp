#define HL_NAME(n) heapsandroid_##n
#include <hl.h>
#undef _GUID
#include <AL/alc.h>
#include <AL/alext.h>
#include "audio_gate.h"
#include "gate_controller.h"

namespace {
LPALCDEVICEPAUSESOFT pauseFunction = nullptr;
LPALCDEVICERESUMESOFT resumeFunction = nullptr;
bool prepareDevice(void *value) {
    auto *device = static_cast<ALCdevice *>(value);
    if (!alcIsExtensionPresent(device, "ALC_SOFT_pause_device")) return false;
    auto pause = reinterpret_cast<LPALCDEVICEPAUSESOFT>(alcGetProcAddress(device, "alcDevicePauseSOFT"));
    auto resume = reinterpret_cast<LPALCDEVICERESUMESOFT>(alcGetProcAddress(device, "alcDeviceResumeSOFT"));
    if (!pause || !resume) return false;
    pauseFunction = pause;
    resumeFunction = resume;
    return true;
}
void pauseDevice(void *value) {
    if (pauseFunction) pauseFunction(static_cast<ALCdevice *>(value));
}
int checkDeviceHealth(void *value) {
    auto *device = static_cast<ALCdevice *>(value);
    // Device queries need no current context; never use alcGetCurrentContext
    // from Java callbacks. The controller holds the lifetime mutex here.
    if (alcGetError(device) != ALC_NO_ERROR) return AUDIO_ERROR_BACKEND_FAILURE;
    if (alcIsExtensionPresent(device, "ALC_EXT_disconnect")) {
        ALCint connected = ALC_FALSE;
        alcGetIntegerv(device, ALC_CONNECTED, 1, &connected);
        if (alcGetError(device) != ALC_NO_ERROR) return AUDIO_ERROR_BACKEND_FAILURE;
        if (connected != ALC_TRUE) return AUDIO_ERROR_DISCONNECTED;
    }
    return alcGetError(device) == ALC_NO_ERROR ? AUDIO_ERROR_NONE : AUDIO_ERROR_BACKEND_FAILURE;
}
bool resumeDevice(void *value) {
    auto *device = static_cast<ALCdevice *>(value);
    // A stale device error is a failure too: do not discard a health fault.
    if (alcGetError(device) != ALC_NO_ERROR) return false;
    resumeFunction(device);
    if (alcGetError(device) != ALC_NO_ERROR) return false;
    return true;
}
AudioGateController gate({prepareDevice, pauseDevice, resumeDevice, checkDeviceHealth});
}

extern "C" int audio_register(void *device) { return gate.registerDevice(device); }
extern "C" void audio_unregister() { gate.unregisterDevice(); }
extern "C" void audio_unregister_device(void *device) { gate.unregisterDevice(device); }
extern "C" void audio_set_foreground(int foreground) { gate.setForeground(foreground != 0); }
extern "C" void audio_set_window_focus(int focused) { gate.setWindowFocus(focused != 0); }
extern "C" void audio_set_sdk_active(int active) { gate.setSdkActive(active != 0); }
extern "C" void audio_route_changed() { gate.routeChanged(); }
extern "C" void audio_begin_focus_request(int generation) { gate.beginFocusRequest(generation); }
extern "C" void audio_set_focus(int generation, int focused) { gate.setFocus(generation, focused != 0); }
extern "C" void audio_abandon_focus(int generation) { gate.abandonFocus(generation); }
extern "C" void audio_set_intent(int intent) { gate.setIntent(intent != 0); }
extern "C" int audio_get_state() { return gate.state(); }
extern "C" int audio_get_error() { return gate.error(); }
extern "C" int audio_check_health() { return gate.checkHealth(); }

// Java callbacks use the plain C entry points above. Only the Heaps thread
// invokes these HashLink primitives, none of which allocate managed objects.
HL_PRIM int HL_NAME(audio_register_device)(ALCdevice *device) { return audio_register(device); }
HL_PRIM void HL_NAME(audio_unregister_device)() { audio_unregister(); }
HL_PRIM void HL_NAME(audio_set_intent)(bool intent) { audio_set_intent(intent ? 1 : 0); }
HL_PRIM int HL_NAME(audio_get_state)() { return audio_get_state(); }
HL_PRIM int HL_NAME(audio_get_error)() { return audio_get_error(); }
HL_PRIM int HL_NAME(audio_check_health)() { return audio_check_health(); }
DEFINE_PRIM(_I32, audio_get_error, _NO_ARG);
DEFINE_PRIM(_I32, audio_check_health, _NO_ARG);
DEFINE_PRIM(_I32, audio_register_device, _ABSTRACT(alc_device));
DEFINE_PRIM(_VOID, audio_unregister_device, _NO_ARG);
DEFINE_PRIM(_VOID, audio_set_intent, _BOOL);
DEFINE_PRIM(_I32, audio_get_state, _NO_ARG);
