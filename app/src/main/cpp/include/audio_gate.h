#ifndef HEAPS_ANDROID_AUDIO_GATE_H
#define HEAPS_ANDROID_AUDIO_GATE_H

enum AudioGateState {
    AUDIO_GATE_UNREGISTERED = 0,
    AUDIO_GATE_PAUSED = 1,
    AUDIO_GATE_RUNNING = 2
};
#ifdef __cplusplus
extern "C" {
#endif
int audio_register(void *device);
void audio_unregister(void);
void audio_set_foreground(int foreground);
void audio_begin_focus_request(int generation);
void audio_set_focus(int generation, int focused);
void audio_abandon_focus(int generation);
void audio_set_intent(int wants_running);
int audio_get_state(void);
#ifdef __cplusplus
}
#endif
#endif
