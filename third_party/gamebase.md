# GameBase import and Android adaptations

GameBase source/resources originate from deepnight/gameBase master, revision `a7af1d70dbbf62d7fc09cb05431ced606e0ed809`, under the MIT license in `licenses/gamebase/LICENSE`. The checksum-pinned source archive is recorded in `dependencies.lock.json`.

`src/game/` is the editable application foundation. The import retains Boot, App, Game, Entity, Level, Camera, Fx, asset builders, UI and tools. The upstream SampleGame/SamplePlayer classes are omitted. The LDtk world retains its generated identifiers and empty collision/entity layers so new game content can be added without an arcade or platformer demo.

Android adaptations:

- Boot prepares/initializes the Android host and shuts it down when disposed.
- App starts an empty Game, uses embedded resources for Android, initializes checked SDK audio and writes fatal crash logs to private storage rather than using desktop paths/dialogs.
- The process loop reconciles SDK foreground/focus before gameplay. A lifecycle loss latches a gameplay pause; focus gain does not undo it. Features pause gameplay independently and preserve existing user/lifecycle pauses.
- `src/demo/FeaturesOverlay.hx` owns the touch-accessible proof UI independently of GameBase scene scaling. The proof screen's WAV fixtures live in `res/android/`.
- Controller resources and event/lifecycle subscriptions are disposed with App. Atlas time is updated once per Boot frame.
- Screenshot mode participates in pause ownership; atlas timing follows Game's slow motion; Game disposes its controller access on restart.
- `ui/component/ControlsHelp.hx` uses its `label` argument; upstream referred to an undefined `txt`. The HLC build includes retained UI/entity modules so dormant framework helpers are type-checked too.
- Debug Console uses deepnightLibs' current `AbstractEnumValue<Int>` type instead of an obsolete anonymous-object type, so `haxe game.hxml -debug` compiles.

The build preserves this repository's patched Heaps and HashLink instead of upstream's floating dependency install commands. Pinned deepnightLibs and LDtk API sources use Apache-2.0, CastleDB uses its public-domain notice, and hscript/heaps-aseprite/ase use their bundled licenses. All notices are copied under `licenses/`; dependencies retain their licenses independently of the MIT template.

To compare future upstream changes, extract the locked GameBase archive, compare `src/game/` and `res/`, then reapply the adaptations listed above. The Android host/audio patches remain covered by the existing pinned patch matrix.
