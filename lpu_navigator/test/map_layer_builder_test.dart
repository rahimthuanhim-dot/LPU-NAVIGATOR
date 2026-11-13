import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lpu_navigator/data/models/campus_dataset.dart';
import 'package:lpu_navigator/data/repositories/campus_repository.dart';
import 'package:lpu_navigator/services/map/map_layer_builder.dart';

Future<CampusDataset> _dataset() => CampusRepository(
  loader: (_) => File('assets/data/campus.json').readAsString(),
).load();

void main() {
  test('builds one deterministic feature for each dataset map item', () async {
    final dataset = await _dataset();
    final builder = MapLayerBuilder();
    final first = builder.build(dataset);
    final second = builder.build(dataset);
    final features = first['features'] as List<dynamic>;

    expect(
      features.where((feature) => feature['properties']['kind'] == 'building'),
      hasLength(3),
    );
    expect(
      features.where(
        (feature) => feature['properties']['kind'] == 'building_label',
      ),
      hasLength(dataset.buildings.length),
    );
    expect(
      features.where((feature) => feature['properties']['kind'] == 'path'),
      hasLength(dataset.edges.length),
    );
    expect(
      features.where((feature) => feature['properties']['kind'] == 'entrance'),
      hasLength(dataset.entrances.length),
    );

    final paths = {
      for (final feature in features.where(
        (feature) => feature['properties']['kind'] == 'path',
      ))
        feature['properties']['id'] as String:
            feature['geometry']['coordinates'],
    };
    for (final edge in dataset.edges) {
      expect(
        paths[edge.id],
        edge.geometry.map((point) => [point.lon, point.lat]).toList(),
      );
    }

    expect(jsonEncode(first), jsonEncode(second));
  });
}
