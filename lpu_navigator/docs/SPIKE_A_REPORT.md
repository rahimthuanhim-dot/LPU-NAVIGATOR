# Offline Map Feasibility Spike

## Result

**Resolved on the available Android emulator.** The bundled background,
polygons, lines, points, and labels render offline. The app does not require a
network connection for the style, GeoJSON, or glyph range.

## Root cause

The previously stated embedded PBF stack-name mismatch was **not confirmed**.
Step 1 showed the cached glyph file was present, byte-identical to the bundled
file, and the runtime style used the matching stack name. App-only Logcat did
not report a glyph-fetch or parse error.

The confirmed cause was the space-containing glyph directory/font-stack name.
With `Klokantech Noto Sans Regular`, the native renderer logged no useful
failure but rendered no labels in the baseline screenshot. Renaming the
directory and requesting `NotoSansRegular` made labels render immediately;
this was the only experiment needed.

The app's native file-loading approach was correct: Flutter copies the style,
GeoJSON, and glyph file into app-specific cache storage, and the style points
the native renderer at `file://` URLs. The MapLibre Flutter documentation
explicitly requires this approach because native engines cannot resolve
Flutter's `asset://` glyph paths.

## Exact correction

- Changed `text-font` to `["NotoSansRegular"]`.
- Renamed the bundled glyph directory and asset path to `NotoSansRegular`.
- Updated startup copying to use the same exact font-stack name.
- Added startup checks for offline URL schemes and required glyph files.
- Added a 15-second style-load timeout with an on-screen error.
- Kept the existing `file://__APP_STORAGE__/glyphs/{fontstack}/{range}.pbf`
  template and all polygon, line, point, camera, and pan/zoom behavior.

## Font and glyph source

The glyph file is the generated `0-255.pbf` output from the OpenMapTiles
`fonts` project, using its patched Noto Sans output. The file uses the
fontnik/Mapbox glyph protobuf format. The applicable licence is bundled at
`docs/licences/NotoSans-OFL.txt`.

- Source repository: https://github.com/openmaptiles/fonts
- Source font configuration: `noto-sans/fonts.json`
- Glyph format: https://github.com/mapbox/fontnik/blob/master/proto/glyphs.proto
- Font license: SIL Open Font License 1.1
- License text: `noto-sans/LICENSE` in the source repository

The PBF is a generated derivative glyph representation, not a silently
introduced runtime font or mapping dependency. The source license permits
bundling and redistribution with software, provided the license notice is
included.

## Toolchain and dependency versions

- Flutter 3.50.0, stable, framework `ab2912035e`, Dart 3.14.0, DevTools
  2.61.0.
- Android SDK 36.0.0, platform android-36, build-tools 36.0.0, emulator
  37.2.13, NDK 28.2.13676358.
- Microsoft OpenJDK 21.0.13.
- Direct runtime dependency: `maplibre_gl` 0.28.0.
- No additional mapping, GPS, search, database, or network dependency was
  added.

## Validation

- `flutter analyze`: completed with no errors; one existing Flutter
  deprecation info remains, so the command exits non-zero under the current
  analyzer policy.
- `flutter build apk --debug`: passed.
- `flutter build apk --release`: passed.
- The glyph PBF has a non-empty standard protobuf header, contains
  `Klokantech Noto Sans Regular`, and contains the `0-255` range.
- The sample labels (`PLACEHOLDER North`, `South`, and `East`, plus the other
  ASCII labels) are covered by the bundled `0-255` range.
- The rewritten style still contains no HTTP, HTTPS, or FTP resource.
- Android emulator `emulator-5554` was used for the Phase 0B run.

## Remaining limitations

- Only the Basic Latin `0-255` glyph range is bundled; labels requiring other
  Unicode ranges will not render until those ranges are added.
- The sample geometry remains clearly marked placeholder data and is not
  verified LPU data.
- The native renderer does not expose glyph-fetch failure through the
  style-loaded callback. A broken glyph URL therefore produces a native
  `Failed to load glyph range` Logcat line but does not trigger the style-load
  timeout.

## Phase 0B — Root-cause investigation

### Step 0: device

`adb devices` initially returned no device. The available `lpu_spike` AVD was
started and booted successfully:

```
emulator-5554    device
```

### Step 1: baseline evidence

- After a clean launch, app-only Logcat contained MapLibre initialization
  lines (`libmaplibre.so`, `Mbgl-EGLConfigChooser`, GPU identifier), but no
  glyph, font-stack, 404, glyph parse, or MapLibre error.
- The only font-related baseline line was Android Skia's unrelated
  `fonts_customization.xml` warning.
- Flutter launch output showed a successful debug APK build and launch.
- This workspace is not under Git, so earlier commits could not be inspected.
- Runtime `test.geojson` SHA-256 matched the bundled file:
  `c3e0f6358b89f5b86bd608b0c5589d3efd2645b9e6f74694ad6aebbbebb5c5ea`.
- Runtime glyph SHA-256 matched the bundled file:
  `2b5324d3fcaa58f93c71d4e6ee70eba532f15585401d764daf99efc427a62693`.
- Runtime glyph size was `75,579` bytes; its first 16 bytes were
  `0A-B7-CE-04-0A-1C-4B-6C-6F-6B-61-6E-74-65-63-68`.
- Runtime cache was
  `/data/user/0/com.example.lpu_navigator/code_cache/lpu_navigator_map/`.
  It contained `style.json`, `test.geojson`, and
  `glyphs/Klokantech Noto Sans Regular/0-255.pbf`.
- The exact baseline rewritten style used:

  ```
  glyphs: file:///data/user/0/com.example.lpu_navigator/code_cache/lpu_navigator_map/glyphs/{fontstack}/{range}.pbf
  data:   file:///data/user/0/com.example.lpu_navigator/code_cache/lpu_navigator_map/test.geojson
  text-font: ["Klokantech Noto Sans Regular"]
  ```

  The spaces were literal spaces in the runtime path and URL template, not
  `%20`.
- Baseline screenshot: [before.png](../before.png). It did not show labels.

### Step 2: experiments

| Experiment | Change | Labels visible | Log notes |
|---|---|---:|---|
| X1 | Renamed the glyph directory and `text-font` to `NotoSansRegular`; updated pubspec and copy code | **Yes** | No glyph error; screenshot showed polygons, lines, and multiple labels |
| X2 | Not run | N/A | X1 resolved the issue |
| X3 | Not run | N/A | X1 resolved the issue |
| X4 | Not run | N/A | X1 resolved the issue |

X1 was the minimal confirmed fix. The result is shown in
[after.png](../after.png).

### Step 3: fix and hardening

The final source uses the space-free `NotoSansRegular` stack. Startup now:

1. rejects every parsed `scheme://` value that is not `file://`;
2. checks every `text-font` stack has a `0-255.pbf` glyph file larger than
   1,024 bytes; and
3. reports an on-screen error if the style-loaded callback does not arrive
   within 15 seconds.

### Acceptance tests

1. **Pass.** Uninstalled/reinstalled, cleared app data, disabled Wi-Fi and
   mobile data, enabled airplane mode, launched the app, and visually verified
   polygons, lines, and more than three labels in [after.png](../after.png).
2. **Pass.** Performed a map swipe and double-tap zoom; the viewport moved and
   labels remained visible in the captured post-gesture screenshot.
3. **Partial.** Deleting the cached glyph file and relaunching recovered the
   file from the bundled asset (`75,579` bytes). A deliberately broken glyph
   URL produced this native Logcat line:
   `Failed to load glyph range 0-255 for font stack NotoSansRegular`.
   The style-loaded callback still fired, so the 15-second style-load timeout
   did not show an error. This is a confirmed limitation of that hardening
   mechanism, not a passed timeout test. The broken URL was reverted.
4. **Pass.** Asset style and runtime-rewritten style contain no non-file
   URL schemes.
5. **Pass.** `flutter build apk --release --split-per-abi`:
   - `app-armeabi-v7a-release.apk`: 21,755,489 bytes (20.7 MB)
   - `app-arm64-v8a-release.apk`: 27,266,083 bytes (26.0 MB)
   - `app-x86_64-release.apk`: 28,826,794 bytes (27.5 MB)

The final release build was made after reverting the broken URL test.
