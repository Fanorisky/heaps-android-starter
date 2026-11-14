# GameBase import and Android adaptations

GameBase source/resources originate from deepnight/gameBase master, revision `a7af1d70dbbf62d7fc09cb05431ced606e0ed809`, under the MIT license in `licenses/gamebase/LICENSE`. The checksum-pinned source archive is recorded in `dependencies.lock.json`.

`src/game/` is the editable application foundation. The import retains Boot, App, Game, Entity, Level, Camera, Fx, asset builders, UI and tools. The upstream SampleGame/SamplePlayer classes and original LDtk collision/entity layers are included. SamplePlayer accepts Android touch movement/jump in addition to its original keyboard/gamepad input.

Android adaptations:

- Boot prepares/initializes the Android host and shuts it down when disposed.
- App starts the original SampleGame, uses embedded resources for Android, initializes checked SDK audio and writes fatal crash logs to private storage rather than using desktop paths/dialogs.
- The process loop reconciles SDK foreground/focus before gameplay. A lifecycle loss latches a gameplay pause; focus gain does not undo it. Features pause gameplay independently and preserve existing user/lifecycle pauses.
- `src/demo/FeaturesOverlay.hx` owns landscape touch movement/jump, pause/restart, and a secondary proof UI independently of GameBase scene scaling. The proof screen's WAV fixtures live in `res/android/`.
- Controller resources and event/lifecycle subscriptions are disposed with App. Atlas time is updated once per Boot frame.
- Touch input respects controller/console locks; modal windows participate in pause ownership and cannot undo a user/lifecycle pause when closed.
- Screenshot mode participates in pause ownership; atlas timing follows Game's slow motion; Game disposes its controller access on restart.
- `ui/component/ControlsHelp.hx` uses its `label` argument; upstream referred to an undefined `txt`. The HLC build includes retained UI/entity modules so dormant framework helpers are type-checked too.
- Debug Console uses deepnightLibs' current `AbstractEnumValue<Int>` type instead of an obsolete anonymous-object type, so `haxe game.hxml -debug` compiles.

The build preserves this repository's patched Heaps and HashLink instead of upstream's floating dependency install commands. Pinned deepnightLibs and LDtk API sources use Apache-2.0, CastleDB uses its public-domain notice, and hscript/heaps-aseprite/ase use their bundled licenses. All notices are copied under `licenses/`; dependencies retain their licenses independently of the MIT template.

To compare future upstream changes, extract the locked GameBase archive, compare `src/game/` and `res/`, then reapply the adaptations listed above. The Android host/audio patches remain covered by the existing pinned patch matrix.
