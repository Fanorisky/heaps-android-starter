# GameBase Android foundation

Replace the Neon Drift application with deepnight/gameBase master at a7af1d70dbbf62d7fc09cb05431ced606e0ed809. The user's request authorizes removing the existing game; the follow-up “continue” authorizes the described integration. Start an empty GameBase game, with no platformer player or Neon Drift gameplay.

Keep the Android Java/JNI host, HashLink/C build, three ABIs, audio gating and reusable heapsandroid APIs. Keep the proof application ID and signing identity so preferences survive upgrades. Import GameBase's Boot/App/Game/process/entity/camera/UI/tool/asset structure with its MIT notice; pin its Haxe dependencies alongside the existing native dependency lock. Retain the repository's patched Heaps and HashLink rather than running upstream's unpinned setup.hxml.

Use res/ for embedded GameBase fonts, atlas, constants and LDtk world. Remove sample player classes and blank the sample level's collision artwork while retaining an editable LDtk foundation. Keep the deterministic WAVs solely as Android API test resources under res/android; delete the ship art, arcade model, score persistence and their tests. Retain SDK regression fixtures and a touch-accessible Android Features overlay independent of gameplay.

Prepare Android before the window; initialize SDK before GameBase's audio Manager. Disable desktop live resource loading and desktop dialogs on Android. Pause GameBase on background/focus loss and require an explicit resume. Dispose subscriptions and SDK resources with the application. Update automation to navigate the empty foundation, exercise Features, return to GameBase and verify preferences across process restart.

Validation: compile actual GameBase to native HLC; run retained pure, Java and sanitized native tests, deterministic audio checks and patch matrix; build and verify the APK if the SDK can be installed here. Report any runtime/device checks unavailable. Old verification records remain historical, with new evidence labeled separately.
