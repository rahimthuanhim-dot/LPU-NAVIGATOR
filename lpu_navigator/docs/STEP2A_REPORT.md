# Step 2A report

## Files changed

- `lib/core/constants.dart`
- `lib/core/problems.dart`
- `lib/services/map/map_asset_provisioner.dart`
- `lib/services/offline_readiness/offline_readiness_service.dart`
- `lib/application/map_controller.dart`
- `lib/presentation/home/home_screen.dart`
- `lib/presentation/widgets/offline_status_chip.dart`
- `lib/app.dart`
- `lib/main.dart`
- `test/map_asset_provisioner_test.dart`
- `test/offline_readiness_service_test.dart`
- `test/offline_status_chip_test.dart`
- `docs/STEP2A_REPORT.md`
- `docs/STEP2A_DEVICE_AIRPLANE.png`
- `docs/STEP2A_DEVICE_AFTER_REPROVISION.png`

No dependencies, Flutter assets, or `tools/` files were changed. The existing
space-free `NotoSansRegular` glyph path and placeholder map assets remain
unchanged.

## Decisions and implementation

- Existing provisioning was moved from `main.dart` into an injectable
  `MapAssetProvisioner`. It validates JSON, rejects non-`file://` schemes,
  rewrites `__APP_STORAGE__`, copies all referenced glyph stacks, and returns
  typed `MapProblem` values instead of throwing.
- `OfflineReadinessService` exposes checking, ready, and problem states.
- `MapController` owns readiness and the existing 15-second style-load timeout.
- The home screen keeps the existing MapLibre camera, compass, attribution, and
  placeholder style/data while adding the requested status, disabled search,
  and disabled location controls.
- The known native limitation is documented in code: native glyph-load
  failures do not trigger the style-loaded callback.

## Acceptance results

### 1. Flutter analyze — **fail (pre-existing infos only)**

Command:

```powershell
flutter analyze
```

The executable was run as `C:\src\flutter\bin\flutter.bat` with the required
tool paths configured. Exact output:

```text
Analyzing lpu_navigator...

   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\app.dart:1:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\presentation\home\home_screen.dart:3:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\presentation\widgets\offline_status_chip.dart:1:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - test\offline_status_chip_test.dart:1:1 - deprecated_member_use

4 issues found. (ran in 6.5s)
```

There are no analyzer errors or newly introduced warnings. The Material
deprecation is emitted by the current Flutter SDK.

### 2. Flutter test — **pass**

Command:

```powershell
flutter test
```

Exact final output:

```text
00:00 +0: loading C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/map_asset_provisioner_test.dart
00:00 +0: C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/offline_status_chip_test.dart: renders all three offline states
00:00 +1: C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/offline_status_chip_test.dart: renders all three offline states
00:00 +2: C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/offline_status_chip_test.dart: renders all three offline states
00:00 +3: C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/offline_status_chip_test.dart: renders all three offline states
00:00 +4: C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/offline_status_chip_test.dart: renders all three offline states
00:00 +5: C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/offline_status_chip_test.dart: renders all three offline states
00:00 +6: C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/offline_status_chip_test.dart: renders all three offline states
00:00 +7: C:/WEBS/LPU NAVIGATOR/lpu_navigator/test/offline_status_chip_test.dart: renders all three offline states
00:00 +8: All tests passed!
```

Result: 8 tests passed.

### 3. Airplane-mode device render — **pass**

The emulator was launched and detected:

```text
flutter emulators --launch lpu_spike
emulator-5554          device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa transport_id:2
```

Debug command:

```powershell
flutter run -d emulator-5554 --debug
```

The debug APK built, installed, and launched successfully. Airplane mode was
set with:

```powershell
adb shell settings put global airplane_mode_on 1
adb shell settings get global airplane_mode_on
```

The final value was `1`. The airplane-mode broadcast command was denied by the
emulator's shell permission policy, but the settings value and airplane icon
confirmed airplane mode. The captured screenshot shows:

- polygons and lines rendered;
- placeholder labels rendered;
- green `Offline ready` chip;
- disabled search field reading `Search destinations (coming soon)`;
- disabled location control.

Screenshot: `docs/STEP2A_DEVICE_AIRPLANE.png`.

### 4. Cached glyph deletion and relaunch — **pass**

The cached glyph was deleted with:

```powershell
adb shell am force-stop com.example.lpu_navigator
adb shell run-as com.example.lpu_navigator rm -f /data/user/0/com.example.lpu_navigator/code_cache/lpu_navigator_map/glyphs/NotoSansRegular/0-255.pbf
adb shell monkey -p com.example.lpu_navigator 1
```

After relaunch, the app was running and the glyph was recreated:

```text
airplane_mode:
1
glyph_cache:
-rw------- 1 u0_a211 u0_a211_cache 75579 2026-11-13 16:38 /data/user/0/com.example.lpu_navigator/code_cache/lpu_navigator_map/glyphs/NotoSansRegular/0-255.pbf
app_process:
3079
```

The post-reprovision screenshot again shows the map and `Offline ready`:
`docs/STEP2A_DEVICE_AFTER_REPROVISION.png`.

### 5. Release APK — **pass**

Command:

```powershell
flutter build apk --release --target-platform android-arm64
```

Exact relevant output:

```text
Running Gradle task 'assembleRelease'...
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 1540 bytes (99.9% reduction).
Running Gradle task 'assembleRelease'... 84.2s
√ Built build\app\outputs\flutter-apk\app-release.apk (45.8MB)
```

Exact file size: `48,061,890` bytes.

## Remaining limitations

- The Flutter SDK reports the existing `material.dart` deprecation infos.
- The native MapLibre glyph-load limitation remains: a native glyph failure
  does not invoke the style-loaded callback.
