#include "../../include/audio_gate.h"
#include <AL/alc.h>
#include <AL/alext.h>
#include <cassert>
#include <iostream>

// Real ALC API calls using OpenAL's host null backend. This verifies error
// detection/latching and lifetime integration, not speaker/headset hardware.
int main() {
    assert(audio_register(nullptr) == 0 && audio_get_error() == AUDIO_ERROR_NO_DEVICE);
    ALCdevice *device = alcOpenDevice(nullptr);
    assert(device && alcIsExtensionPresent(device, "ALC_SOFT_pause_device"));
    ALCcontext *context = alcCreateContext(device, nullptr);
    assert(context && alcMakeContextCurrent(context));
    audio_set_sdk_active(1); audio_set_foreground(1); audio_set_window_focus(1);
    assert(audio_register(device) == 1);
    assert(audio_get_state() == AUDIO_GATE_PAUSED);
    audio_begin_focus_request(1); audio_set_focus(1, 1); audio_set_intent(1);
    assert(audio_get_state() == AUDIO_GATE_RUNNING);
    // The real ALC operation, not a substituted controller, sets an error.
    ALCint ignored = 0;
    alcGetIntegerv(device, static_cast<ALCenum>(0x7fffffff), 1, &ignored);
    assert(audio_get_state() == AUDIO_GATE_UNREGISTERED);
    assert(audio_get_error() == AUDIO_ERROR_BACKEND_FAILURE);
    assert(audio_check_health() == AUDIO_ERROR_BACKEND_FAILURE);
    audio_set_intent(1); audio_set_foreground(1);
    assert(audio_get_state() == AUDIO_GATE_UNREGISTERED); // consumed error remains latched
    audio_unregister_device(device); alcMakeContextCurrent(nullptr); alcDestroyContext(context); assert(alcCloseDevice(device));
    device = alcOpenDevice(nullptr); assert(device);
    context = alcCreateContext(device, nullptr); assert(context && alcMakeContextCurrent(context));
    assert(audio_register(device) == 1);
    assert(audio_get_state() == AUDIO_GATE_PAUSED && audio_get_error() == AUDIO_ERROR_NONE);
    audio_unregister_device(device); alcMakeContextCurrent(nullptr); alcDestroyContext(context); assert(alcCloseDevice(device));
    assert(audio_get_state() == AUDIO_GATE_UNREGISTERED);
    std::cout << "AUDIO_ALC_NULL_BACKEND_TEST_PASS (hardware unverified)\n";
}
