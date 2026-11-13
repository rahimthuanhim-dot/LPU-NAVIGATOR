import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpu_navigator/services/map/map_asset_provisioner.dart';
import 'package:lpu_navigator/services/offline_readiness/offline_readiness_service.dart';

ByteData _data(String value) =>
    ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));

void main() {
  const style = '''
{"version":8,"glyphs":"file://__APP_STORAGE__/glyphs/{fontstack}/{range}.pbf",
"layers":[{"layout":{"text-font":["NotoSansRegular"]}}]}
''';
  const geoJson = '{"type":"FeatureCollection","features":[]}';

  Future<Directory> makeStorage() => Directory.systemTemp.createTemp('lpu-ready-');

  MapAssetLoader loader(bool valid) {
    return (asset) async {
      if (asset.endsWith('style.json')) return _data(valid ? style : '{');
      if (asset.endsWith('test.geojson')) return _data(geoJson);
      return ByteData.sublistView(Uint8List(2048)..fillRange(0, 2048, 1));
    };
  }

  test('starts checking and becomes ready', () async {
    final storage = await makeStorage();
    addTearDown(() => storage.delete(recursive: true));
    final service = OfflineReadinessService(
      MapAssetProvisioner(storage: storage, assetLoader: loader(true)),
    );

    expect(service.current.state, OfflineReadinessState.checking);
    final result = await service.check();

    expect(result.state, OfflineReadinessState.ready);
  });

  test('becomes problem when provisioning fails', () async {
    final storage = await makeStorage();
    addTearDown(() => storage.delete(recursive: true));
    final service = OfflineReadinessService(
      MapAssetProvisioner(storage: storage, assetLoader: loader(false)),
    );

    final result = await service.check();

    expect(result.state, OfflineReadinessState.problem);
    expect(result.problems, isNotEmpty);
  });
}
