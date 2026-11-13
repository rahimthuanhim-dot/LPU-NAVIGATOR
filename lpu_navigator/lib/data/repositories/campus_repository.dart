import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/building.dart';
import '../models/campus_dataset.dart';
import '../models/entrance.dart';
import '../models/graph_edge.dart';
import '../models/graph_node.dart';

typedef CampusAssetLoader = Future<String> Function(String assetPath);

class DatasetException implements Exception {
  const DatasetException(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => 'DatasetException at $path: $message';
}

class CampusRepository {
  CampusRepository({
    CampusAssetLoader? loader,
    this.assetPath = 'assets/data/campus.json',
  }) : loader = loader ?? rootBundle.loadString;

  final CampusAssetLoader loader;
  final String assetPath;

  Future<CampusDataset> load() async {
    late final String text;
    try {
      text = await loader(assetPath);
    } on Object catch (error) {
      throw DatasetException(assetPath, 'Could not load dataset: $error');
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('root must be an object');
      }
      return _parse(decoded);
    } on DatasetException {
      rethrow;
    } on FormatException catch (error) {
      throw DatasetException(assetPath, error.message);
    } on Object catch (error) {
      throw DatasetException(assetPath, '$error');
    }
  }

  CampusDataset _parse(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion', 'schemaVersion');
    final dataVersion = _requiredString(json, 'dataVersion', 'dataVersion');
    final builtAt = _requiredString(json, 'builtAt', 'builtAt');
    final bboxJson = _requiredMap(json, 'bbox', 'bbox');
    final kind = _requiredString(json, 'datasetKind', 'datasetKind');
    final buildingsJson = _requiredList(json, 'buildings', 'buildings');
    final entrancesJson = _requiredList(json, 'entrances', 'entrances');
    final nodesJson = _requiredList(json, 'nodes', 'nodes');
    final edgesJson = _requiredList(json, 'edges', 'edges');
    return CampusDataset(
      schemaVersion: schemaVersion,
      dataVersion: dataVersion,
      builtAt: builtAt,
      bbox: CampusBounds(
        south: _requiredNumber(bboxJson, 'south', 'bbox.south'),
        west: _requiredNumber(bboxJson, 'west', 'bbox.west'),
        north: _requiredNumber(bboxJson, 'north', 'bbox.north'),
        east: _requiredNumber(bboxJson, 'east', 'bbox.east'),
      ),
      datasetKind: _datasetKind(kind, 'datasetKind'),
      buildings: List.unmodifiable([
        for (var index = 0; index < buildingsJson.length; index++)
          Building.fromJson(
            _map(buildingsJson[index], 'buildings[$index]'),
            'buildings[$index]',
          ),
      ]),
      entrances: List.unmodifiable([
        for (var index = 0; index < entrancesJson.length; index++)
          Entrance.fromJson(
            _map(entrancesJson[index], 'entrances[$index]'),
            'entrances[$index]',
          ),
      ]),
      nodes: List.unmodifiable([
        for (var index = 0; index < nodesJson.length; index++)
          GraphNode.fromJson(
            _map(nodesJson[index], 'nodes[$index]'),
            'nodes[$index]',
          ),
      ]),
      edges: List.unmodifiable([
        for (var index = 0; index < edgesJson.length; index++)
          GraphEdge.fromJson(
            _map(edgesJson[index], 'edges[$index]'),
            'edges[$index]',
          ),
      ]),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$path must be a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! int) throw FormatException('$path must be an integer');
  return value;
}

double _requiredNumber(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! num) throw FormatException('$path must be a number');
  return value.toDouble();
}

Map<String, dynamic> _requiredMap(
  Map<String, dynamic> json,
  String key,
  String path,
) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path must be an object');
  }
  return value;
}

List<dynamic> _requiredList(
  Map<String, dynamic> json,
  String key,
  String path,
) {
  final value = json[key];
  if (value is! List) throw FormatException('$path must be an array');
  return value;
}

Map<String, dynamic> _map(Object? value, String path) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path must be an object');
  }
  return value;
}

DatasetKind _datasetKind(String value, String path) {
  switch (value) {
    case 'PLACEHOLDER':
      return DatasetKind.placeholder;
    case 'SURVEYED':
      return DatasetKind.surveyed;
    default:
      throw FormatException('$path must be PLACEHOLDER or SURVEYED');
  }
}
