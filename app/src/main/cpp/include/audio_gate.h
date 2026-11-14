#ifndef HEAPS_ANDROID_AUDIO_GATE_H
#define HEAPS_ANDROID_AUDIO_GATE_H

enum AudioGateState {
    AUDIO_GATE_UNREGISTERED = 0,
    AUDIO_GATE_PAUSED = 1,
    AUDIO_GATE_RUNNING = 2
};
enum AudioGateError { AUDIO_ERROR_NONE=0, AUDIO_ERROR_NO_DEVICE=1, AUDIO_ERROR_UNSUPPORTED=2, AUDIO_ERROR_DISCONNECTED=3, AUDIO_ERROR_BACKEND_FAILURE=4, AUDIO_ERROR_RESUME_FAILURE=5 };
#ifdef __cplusplus
extern "C" {
#endif
int audio_register(void *device);
void audio_unregister(void);
/* Native close wrappers clear only this device before destroying it. */
void audio_unregister_device(void *device);
void audio_set_foreground(int foreground);
void audio_set_window_focus(int focused);
void audio_set_sdk_active(int active);
void audio_route_changed(void);
void audio_begin_focus_request(int generation);
void audio_set_focus(int generation, int focused);
void audio_abandon_focus(int generation);
void audio_set_intent(int wants_running);
int audio_get_state(void);
int audio_get_error(void);
int audio_check_health(void);
#ifdef __cplusplus
}
#endif
#endif
