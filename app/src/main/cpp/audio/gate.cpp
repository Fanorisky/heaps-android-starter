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
void pauseDevice(void *value) { pauseFunction(static_cast<ALCdevice *>(value)); }
bool resumeDevice(void *value) {
    auto *device = static_cast<ALCdevice *>(value);
    // Report this operation's result, not an older unrelated ALC error.
    alcGetError(device);
    resumeFunction(device);
    if (alcGetError(device) != ALC_NO_ERROR) return false;
    if (alcIsExtensionPresent(device, "ALC_EXT_disconnect")) {
        ALCint connected = ALC_FALSE;
        alcGetIntegerv(device, ALC_CONNECTED, 1, &connected);
        if (alcGetError(device) != ALC_NO_ERROR || connected != ALC_TRUE) return false;
    }
    return true;
}
AudioGateController gate({prepareDevice, pauseDevice, resumeDevice});
}

extern "C" int audio_register(void *device) { return gate.registerDevice(device); }
extern "C" void audio_unregister() { gate.unregisterDevice(); }
extern "C" void audio_unregister_device(void *device) { gate.unregisterDevice(device); }
extern "C" void audio_set_foreground(int foreground) { gate.setForeground(foreground != 0); }
extern "C" void audio_begin_focus_request(int generation) { gate.beginFocusRequest(generation); }
extern "C" void audio_set_focus(int generation, int focused) { gate.setFocus(generation, focused != 0); }
extern "C" void audio_abandon_focus(int generation) { gate.abandonFocus(generation); }
extern "C" void audio_set_intent(int intent) { gate.setIntent(intent != 0); }
extern "C" int audio_get_state() { return gate.state(); }

// Java callbacks use the plain C entry points above. Only the Heaps thread
// invokes these HashLink primitives, none of which allocate managed objects.
HL_PRIM int HL_NAME(audio_register_device)(ALCdevice *device) { return audio_register(device); }
HL_PRIM void HL_NAME(audio_unregister_device)() { audio_unregister(); }
HL_PRIM void HL_NAME(audio_set_intent)(bool intent) { audio_set_intent(intent ? 1 : 0); }
HL_PRIM int HL_NAME(audio_get_state)() { return audio_get_state(); }
DEFINE_PRIM(_I32, audio_register_device, _ABSTRACT(alc_device));
DEFINE_PRIM(_VOID, audio_unregister_device, _NO_ARG);
DEFINE_PRIM(_VOID, audio_set_intent, _BOOL);
DEFINE_PRIM(_I32, audio_get_state, _NO_ARG);
