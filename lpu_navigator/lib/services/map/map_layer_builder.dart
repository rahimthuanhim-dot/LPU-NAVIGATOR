import 'dart:convert';

import '../../data/models/campus_dataset.dart';

class MapLayerBuilder {
  Map<String, dynamic> build(CampusDataset dataset) {
    final buildings = [...dataset.buildings]
      ..sort((a, b) => a.id.compareTo(b.id));
    final edges = [...dataset.edges]..sort((a, b) => a.id.compareTo(b.id));
    final entrances = [...dataset.entrances]
      ..sort((a, b) => a.id.compareTo(b.id));
    final nodes = {for (final node in dataset.nodes) node.id: node};
    final features = <Map<String, dynamic>>[];

    for (final building in buildings) {
      final footprint = building.footprint;
      if (footprint == null || footprint.length < 3) continue;
      features.add(
        _feature(
          geometry: {
            'type': 'Polygon',
            'coordinates': [
              [
                ...footprint.map((point) => [point.lon, point.lat]),
                [footprint.first.lon, footprint.first.lat],
              ],
            ],
          },
          properties: {
            'kind': 'building',
            'id': building.id,
            'name': building.name,
            'category': building.category,
          },
        ),
      );
    }

    for (final building in buildings) {
      features.add(
        _feature(
          geometry: {
            'type': 'Point',
            'coordinates': [building.lon, building.lat],
          },
          properties: {
            'kind': 'building_label',
            'id': building.id,
            'name': building.name,
          },
        ),
      );
    }

    for (final edge in edges) {
      features.add(
        _feature(
          geometry: {
            'type': 'LineString',
            'coordinates': [
              for (final point in edge.geometry) [point.lon, point.lat],
            ],
          },
          properties: {
            'kind': 'path',
            'id': edge.id,
            'pathwayType': edge.pathwayType,
          },
        ),
      );
    }

    for (final entrance in entrances) {
      final node = nodes[entrance.nodeId];
      if (node == null) {
        throw StateError(
          'Entrance "${entrance.id}" references missing node '
          '"${entrance.nodeId}".',
        );
      }
      features.add(
        _feature(
          geometry: {
            'type': 'Point',
            'coordinates': [node.lon, node.lat],
          },
          properties: {
            'kind': 'entrance',
            'id': entrance.id,
            'buildingId': entrance.buildingId,
          },
        ),
      );
    }

    return {'type': 'FeatureCollection', 'features': features};
  }

  String buildJson(CampusDataset dataset) => jsonEncode(build(dataset));

  Map<String, dynamic> _feature({
    required Map<String, dynamic> geometry,
    required Map<String, dynamic> properties,
  }) {
    return {'type': 'Feature', 'geometry': geometry, 'properties': properties};
  }
}
