import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lpu_navigator/data/models/campus_dataset.dart';
import 'package:lpu_navigator/data/repositories/campus_repository.dart';
import 'package:lpu_navigator/data/validation/dataset_validator.dart';

Future<Map<String, dynamic>> _rawDataset() async {
  final text = await File('assets/data/campus.json').readAsString();
  return jsonDecode(text) as Map<String, dynamic>;
}

Future<CampusDataset> _dataset(
  void Function(Map<String, dynamic> json) mutate,
) async {
  final json = await _rawDataset();
  mutate(json);
  return CampusRepository(loader: (_) async => jsonEncode(json)).load();
}

void main() {
  test('placeholder dataset parses and validates with zero errors', () async {
    final dataset = await _dataset((_) {});
    final report = DatasetValidator().validate(dataset);

    expect(report.errors, isEmpty);
    expect(dataset.datasetKind, DatasetKind.placeholder);
    expect(dataset.isReleaseSafe, isFalse);
  });

  test('placeholder graph contains a loop', () async {
    final dataset = await _dataset((_) {});
    final nodes = dataset.nodes.map((node) => node.id).toSet();
    final edges = dataset.edges
        .map((edge) => {edge.sourceNodeId, edge.destinationNodeId})
        .map((edge) => edge.toList()..sort())
        .map((edge) => edge.join('|'))
        .toSet();

    expect(edges.length - nodes.length + 1, greaterThanOrEqualTo(1));
  });

  final cases = <String, void Function(Map<String, dynamic>)>{
    'duplicate ids': (json) {
      json['buildings'][1]['id'] = json['buildings'][0]['id'];
    },
    'broken references': (json) {
      json['entrances'][0]['buildingId'] = 'missing-building';
    },
    'coordinates outside bbox': (json) {
      json['nodes'][0]['lat'] = 40;
    },
    'non-positive distance': (json) {
      json['edges'][0]['distanceMeters'] = 0;
    },
    'distance below straight line': (json) {
      json['edges'][0]['distanceMeters'] = 1;
    },
    'geometry length mismatch': (json) {
      json['edges'][0]['distanceMeters'] = 1000;
    },
    'building without entrance': (json) {
      json['entrances'].removeWhere(
        (item) => item['buildingId'] == 'building-placeholder-1',
      );
    },
    'wrong entrance node type': (json) {
      json['nodes'][10]['nodeType'] = 'junction';
    },
    'disconnected graph': (json) {
      json['edges'].clear();
    },
    'footprint crossing': (json) {
      json['edges'][0]['geometry'] = [
        {'lat': 31.249, 'lon': 75.6995},
        {'lat': 31.251, 'lon': 75.6995},
      ];
    },
  };

  for (final entry in cases.entries) {
    test('validator reports ${entry.key}', () async {
      final dataset = await _dataset(entry.value);
      final report = DatasetValidator().validate(dataset);

      expect(report.errors, isNotEmpty);
    });
  }
}
