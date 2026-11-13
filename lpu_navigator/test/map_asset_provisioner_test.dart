import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpu_navigator/services/map/map_asset_provisioner.dart';

const _style = '''
{"version":8,"glyphs":"file://__APP_STORAGE__/glyphs/{fontstack}/{range}.pbf",
"layers":[{"id":"labels","type":"symbol","layout":{"text-font":["NotoSansRegular"]}}]}
''';
const _geoJson = '{"type":"FeatureCollection","features":[]}';

ByteData _data(String value) =>
    ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));

MapAssetLoader _loader({
  String style = _style,
  String geoJson = _geoJson,
  bool includeGlyph = true,
  bool includeGeoJson = true,
}) {
  return (asset) async {
    if (asset == 'assets/map/style.json') return _data(style);
    if (includeGeoJson && asset == 'assets/map/test.geojson') {
      return _data(geoJson);
    }
    if (includeGlyph &&
        asset == 'assets/map/glyphs/NotoSansRegular/0-255.pbf') {
      return ByteData.sublistView(Uint8List(2048)..fillRange(0, 2048, 1));
    }
    throw StateError('not found');
  };
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lpu-map-test-');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('provisions style, GeoJSON, and glyph successfully', () async {
    final result = await MapAssetProvisioner(
      storage: temp,
      assetLoader: _loader(),
    ).provision();

    expect(result.isReady, isTrue);
    expect(File(result.stylePath!).existsSync(), isTrue);
    expect(
      File('${temp.path}/glyphs/NotoSansRegular/0-255.pbf').lengthSync(),
      2048,
    );
  });

  test('reports a missing glyph', () async {
    final result = await MapAssetProvisioner(
      storage: temp,
      assetLoader: _loader(includeGlyph: false),
    ).provision();

    expect(result.problems.single.code, 'missing_asset');
  });

  test('rejects a non-file URL in style', () async {
    final result = await MapAssetProvisioner(
      storage: temp,
      assetLoader: _loader(
        style: _style.replaceFirst(
          'file://__APP_STORAGE__',
          'https://example.invalid',
        ),
      ),
    ).provision();

    expect(result.problems.single.code, 'non_file_url');
  });

  test('reports corrupt style JSON', () async {
    final result = await MapAssetProvisioner(
      storage: temp,
      assetLoader: _loader(style: '{'),
    ).provision();

    expect(result.problems.single.code, 'invalid_style_json');
  });

  test('reports a missing asset', () async {
    final result = await MapAssetProvisioner(
      storage: temp,
      assetLoader: _loader(includeGeoJson: false),
    ).provision();

    expect(result.problems.single.code, 'missing_asset');
  });
}
