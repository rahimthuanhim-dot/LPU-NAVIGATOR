# Step 2C Report

## Files changed

- `lib/services/map/map_layer_builder.dart`
- `lib/core/constants.dart`
- `lib/services/map/map_asset_provisioner.dart`
- `lib/services/offline_readiness/offline_readiness_service.dart`
- `lib/presentation/home/home_screen.dart`
- `lib/presentation/widgets/offline_status_chip.dart`
- `lib/main.dart`
- `assets/map/style.json`
- `pubspec.yaml`
- `test/map_layer_builder_test.dart`
- `test/map_asset_provisioner_test.dart`
- `docs/STEP2A_REPORT.md`
- `docs/STEP2B_REPORT.md`
- `docs/SPIKE_A_REPORT.md`
- `docs/STEP2C_REPORT.md`

## Validation

### `flutter analyze`

Command:

```text
flutter analyze
```

Output:

```text
Analyzing lpu_navigator...

   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\app.dart:1:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\presentation\home\home_screen.dart:3:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\presentation\widgets\offline_status_chip.dart:1:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - test\offline_status_chip_test.dart:1:1 - deprecated_member_use

4 issues found. (ran in 8.6s)
```

**Result: pass.** No new warnings were introduced; the four infos are the existing Material deprecation notices.

### `flutter test`

Command:

```text
flutter test
```

**Result: pass — 25 tests passed.**

## Acceptance checks

| Check | Result | Evidence |
|---|---|---|
| Dataset-driven map renders on the emulator in airplane mode | **fail** | `emulator-5554` showed the readiness chip, placeholder banner, and opaque controls, but the MapLibre canvas was blank. Provisioned `style.json` and `campus_layers.geojson` were present. |
| Three buildings, 15 paths, entrances, and one label per building render | **not run** | Blocked by the blank MapLibre canvas. |
| Top bar, banner, status-bar protection, and opaque controls | **pass** | Emulator screenshot showed the overlays with no map content behind them. |
| Broken dataset reference shows “Map data problem” and draws no map | **not run** | Not run after the device rendering failure. Dataset blocking is covered by the readiness and validator tests. |
| Delete cached glyph and relaunch re-provisions | **not run** | Not run after the device rendering failure. |
| Pan and zoom with overlays | **not run** | Not run because the map was not visible. |
| `isReleaseSafe` unit test | **pass** | Included in the passing Flutter test suite. |

The device diagnostic also changed the style background to vivid red temporarily; the red background was not visible. The required background and kind filters were restored before this report. This indicates the observed failure is at MapLibre platform-view rendering or style loading, not only at the generated feature filters.

## Release builds

### Arm64 APK

Command:

```text
flutter build apk --release --target-platform android-arm64
```

Output:

```text
Built build\app\outputs\flutter-apk\app-release.apk (45.9MB)
```

The APK `lib/` contents were inspected with `System.IO.Compression.ZipFile.OpenRead`:

```text
lib/arm64-v8a/libapp.so         4981720 bytes
lib/arm64-v8a/libflutter.so    11346352 bytes
lib/arm64-v8a/libmaplibre.so   11042072 bytes
lib/armeabi-v7a/libmaplibre.so  8054608 bytes
lib/x86_64/libmaplibre.so      11423144 bytes
```

The arm64 APK contains arm64-v8a application and Flutter libraries. The APK also contains MapLibre native libraries for armeabi-v7a and x86_64.

### Split APKs

Command:

```text
flutter build apk --release --split-per-abi
```

Output:

```text
build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk (22.2MB)
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk (27.3MB)
build\app\outputs\flutter-apk\app-x86_64-release.apk (28.9MB)
```

