# Physical-device reliability checks

Baseline: the user reported the original native game working on Samsung Galaxy A10 / Android11. This establishes that original ARM32 game path; it is not evidence for the new SDK's audio, Bluetooth, routing, battery or latency behavior.

| Scenario | Local/CI/Android emulator | Physical A10 | Another ARM64 phone |
|---|---|---|---|
| Three ABI compile/package/certificate | automated | not a device measurement | not a device measurement |
| Native original game | x86_64 emulator | user-confirmed original version | pending |
| Raw/wrapped audio freeze/resume | real channels + controlled failures | pending | pending |
| SDK shutdown/reinitialize | regression | pending | pending |
| Speaker/WAV/music audible | stream/channel processing only | pending listening test | pending |
| Wired headphones insert/remove | route/focus policy tests | pending | pending |
| Bluetooth connect/disconnect/playback | route/focus policy tests | pending | pending |
| Calls/notifications/lock/unlock | lifecycle/focus policy + framework cycles | pending | pending |
| IME paste/emoji/rotate | native encoding + Android input | pending | pending |
| Vibration/sensors/insets | API/state tests where available | pending physical sensation | pending |
| Audio latency/battery/frame time | not benchmarked | pending measurement | pending measurement |

On each device: record model/Android/app version/ABI; install as an update; verify preferences; run Audio Checks and Stress; perform at least10 HOME/return and lock/unlock cycles; pause raw and muted loops; connect/disconnect wired/Bluetooth output; interrupt with another audio app/call; verify output stays paused until explicit resume; exercise Recover and replay; paste ASCII/CJK/emoji; rotate both orientations. Capture logcat and exact failures. Do not mark a device passed from screenshots alone.

For latency/battery performance, use recorded measurements with method/duration/settings rather than an ungrounded claim that the framework is fast. Hardware testing remains separate from deterministic fault-injection regressions.
