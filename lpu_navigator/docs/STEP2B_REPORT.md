# Step 2B report

## Files changed

- `lib/data/models/geo_point.dart`
- `lib/data/models/building.dart`
- `lib/data/models/entrance.dart`
- `lib/data/models/graph_node.dart`
- `lib/data/models/graph_edge.dart`
- `lib/data/models/campus_dataset.dart`
- `lib/core/geo.dart`
- `lib/data/repositories/campus_repository.dart`
- `lib/data/validation/dataset_validator.dart`
- `lib/services/offline_readiness/offline_readiness_service.dart`
- `lib/presentation/home/home_screen.dart`
- `assets/data/campus.json`
- `pubspec.yaml`
- `test/dataset_validator_test.dart`
- `test/geo_test.dart`
- `test/fixtures/invalid_reference.json`
- `test/offline_readiness_service_test.dart`
- `docs/STEP2B_REPORT.md`

No new packages were added. The dataset is explicitly `PLACEHOLDER`; every
dataset row has `source: "PLACEHOLDER"` and `verified: false`.

## Implementation

- Added immutable JSON models for buildings, entrances, graph nodes, graph
  edges, bounds, and the campus dataset.
- Added haversine distance, polyline length, point-in-polygon, and strict
  segment intersection helpers. Boundary touching, shared endpoints, and
  boundary-following segments are excluded from strict intersections.
- Added injectable campus loading with path-aware `DatasetException` errors.
- Added validation for IDs, references, bounds, edge metrics, entrances,
  connectivity, footprint crossings, aliases, and verification warnings.
  Crossing validation also checks a segment midpoint strictly inside a
  footprint and reports each edge/building pair once.
- Added a connected 12-node, 15-edge placeholder graph with four cycles and
  three rectangular placeholder buildings.
- Dataset validation errors become blocking offline map problems. Warnings do
  not block readiness. The home screen shows `PLACEHOLDER DATA - not verified`
  persistently for the placeholder dataset.

## Acceptance results

### 1. `flutter analyze` — **fail (pre-existing infos only)**

Command:

```powershell
flutter analyze
```

Exact final output:

```text
Analyzing lpu_navigator...

   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\app.dart:1:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\presentation\home\home_screen.dart:3:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - lib\presentation\widgets\offline_status_chip.dart:1:1 - deprecated_member_use
   info - 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement - test\offline_status_chip_test.dart:1:1 - deprecated_member_use

4 issues found. (ran in 5.5s)
```

No analyzer warnings introduced by Step 2B remain.

### 2. `flutter test` — **pass**

Command:

```powershell
flutter test
```

Final output:

```text
00:00 +24: All tests passed!
```

Result: 24 tests passed. This includes model parsing, every validator error
category, placeholder graph cycles, strict crossing cases, readiness states,
provisioning, and the status chip.

### 3. Airplane-mode device run — **pass (Android emulator)**

An Android 15 API 35 emulator was launched:

```text
flutter emulators --launch lpu_spike
sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64
```

The debug app was built and installed with:

```powershell
flutter run -d emulator-5554 --debug
```

The cleared-data and airplane-mode conditions were applied with:

```powershell
adb -s emulator-5554 shell settings put global airplane_mode_on 1
adb -s emulator-5554 shell settings get global airplane_mode_on
adb -s emulator-5554 shell pm clear com.example.lpu_navigator
adb -s emulator-5554 shell monkey -p com.example.lpu_navigator 1
```

The returned airplane-mode value was `1`, and `pm clear` returned `Success`.
The final screenshot and UI hierarchy verify:

- the map renders all three placeholder polygons, labels, and graph lines;
- the chip says `Offline ready`;
- `PLACEHOLDER DATA - not verified` is visible;
- the search field is disabled and displays `Search destinations (coming soon)`;
- the location control is disabled and exposes `GPS not enabled yet`.

Screenshot: `docs/STEP2B_DEVICE_AIRPLANE.png`.

### 4. Broken-reference device check — **not run**

The validator's broken-reference test passes in the Flutter test suite using an
invalid dataset fixture. A modified dataset was not injected into the installed
APK, so the live chip transition to `Map data problem` was not claimed as
device-verified.

### 5. Release arm64 build — **pass**

Command:

```powershell
flutter build apk --release --target-platform android-arm64
```

Exact relevant output:

```text
Running Gradle task 'assembleRelease'...
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 1540 bytes (99.9% reduction).
Running Gradle task 'assembleRelease'... 19.0s
√ Built build\app\outputs\flutter-apk\app-release.apk (45.9MB)
APK_BYTES=48128673
```

## Geometry test results

The focused geometry tests passed for:

- proper crossings;
- shared endpoints;
- endpoint/boundary touching;
- boundary-following segments;
- midpoint-inside classification.

## Remaining limitations

- Device tests ran on an Android emulator only; a physical Android device was
  not used.
- The Flutter SDK continues to report four existing `material.dart`
  deprecation infos.
- The dataset is placeholder data and is not release-safe.
