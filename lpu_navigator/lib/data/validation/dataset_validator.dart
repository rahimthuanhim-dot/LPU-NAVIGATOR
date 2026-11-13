import '../../core/geo.dart';
import '../models/campus_dataset.dart';
import '../models/geo_point.dart';
import '../models/graph_node.dart';

class ValidationReport {
  const ValidationReport({required this.errors, required this.warnings});

  final List<String> errors;
  final List<String> warnings;

  bool get isValid => errors.isEmpty;
}

class DatasetValidator {
  ValidationReport validate(CampusDataset dataset) {
    final errors = <String>[];
    final warnings = <String>[];
    _duplicateIds(dataset, errors);
    _references(dataset, errors);
    _coordinates(dataset, errors);
    _edgeMetrics(dataset, errors);
    _buildingEntrances(dataset, errors);
    _graphConnectivity(dataset, errors);
    _footprintCrossings(dataset, errors);
    _warnings(dataset, warnings);
    return ValidationReport(errors: errors, warnings: warnings);
  }

  void _duplicateIds(CampusDataset dataset, List<String> errors) {
    final tables = <String, List<String>>{
      'buildings': dataset.buildings.map((item) => item.id).toList(),
      'entrances': dataset.entrances.map((item) => item.id).toList(),
      'nodes': dataset.nodes.map((item) => item.id).toList(),
      'edges': dataset.edges.map((item) => item.id).toList(),
    };
    for (final entry in tables.entries) {
      final duplicates = entry.value.toSet().where(
        (id) => entry.value.where((item) => item == id).length > 1,
      );
      for (final id in duplicates) {
        errors.add('Duplicate ${entry.key} id "$id".');
      }
    }
  }

  void _references(CampusDataset dataset, List<String> errors) {
    final buildingIds = dataset.buildings.map((item) => item.id).toSet();
    final nodeIds = dataset.nodes.map((item) => item.id).toSet();
    for (final entrance in dataset.entrances) {
      if (!buildingIds.contains(entrance.buildingId)) {
        errors.add(
          'Entrance "${entrance.id}" references missing building "${entrance.buildingId}".',
        );
      }
      if (!nodeIds.contains(entrance.nodeId)) {
        errors.add(
          'Entrance "${entrance.id}" references missing node "${entrance.nodeId}".',
        );
      }
    }
    for (final edge in dataset.edges) {
      if (!nodeIds.contains(edge.sourceNodeId) ||
          !nodeIds.contains(edge.destinationNodeId)) {
        errors.add('Edge "${edge.id}" references missing graph node.');
      }
    }
  }

  void _coordinates(CampusDataset dataset, List<String> errors) {
    bool outside(GeoPoint point) =>
        point.lat < dataset.bbox.south ||
        point.lat > dataset.bbox.north ||
        point.lon < dataset.bbox.west ||
        point.lon > dataset.bbox.east;
    for (final building in dataset.buildings) {
      if (outside(GeoPoint(lat: building.lat, lon: building.lon))) {
        errors.add('Building "${building.id}" is outside bbox.');
      }
      for (final point in building.footprint ?? const <GeoPoint>[]) {
        if (outside(point)) {
          errors.add('Building "${building.id}" footprint is outside bbox.');
        }
      }
    }
    for (final node in dataset.nodes) {
      if (outside(node.point)) {
        errors.add('Node "${node.id}" is outside bbox.');
      }
    }
    for (final edge in dataset.edges) {
      for (final point in edge.geometry) {
        if (outside(point)) {
          errors.add('Edge "${edge.id}" geometry is outside bbox.');
        }
      }
    }
  }

  void _edgeMetrics(CampusDataset dataset, List<String> errors) {
    final nodes = {for (final node in dataset.nodes) node.id: node};
    for (final edge in dataset.edges) {
      final source = nodes[edge.sourceNodeId];
      final destination = nodes[edge.destinationNodeId];
      if (source == null || destination == null) continue;
      if (edge.distanceMeters <= 0) {
        errors.add(
          'Edge "${edge.id}" distanceMeters must be greater than zero.',
        );
        continue;
      }
      final straight = haversineDistance(source.point, destination.point);
      if (edge.distanceMeters < straight * 0.99) {
        errors.add('Edge "${edge.id}" is below the straight-line distance.');
      }
      final geometryLength = polylineLength(edge.geometry);
      if (geometryLength > 0 &&
          (edge.distanceMeters - geometryLength).abs() / geometryLength >
              0.05) {
        errors.add(
          'Edge "${edge.id}" differs from geometry length by more than 5%.',
        );
      }
    }
  }

  void _buildingEntrances(CampusDataset dataset, List<String> errors) {
    final entranceBuildings = <String>{};
    final nodes = {for (final node in dataset.nodes) node.id: node};
    for (final entrance in dataset.entrances) {
      entranceBuildings.add(entrance.buildingId);
      final node = nodes[entrance.nodeId];
      if (node != null && node.nodeType != GraphNodeType.entrance) {
        errors.add('Entrance "${entrance.id}" node is not type entrance.');
      }
    }
    for (final building in dataset.buildings) {
      if (!entranceBuildings.contains(building.id)) {
        errors.add('Building "${building.id}" has no entrance.');
      }
    }
  }

  void _graphConnectivity(CampusDataset dataset, List<String> errors) {
    if (dataset.nodes.isEmpty) return;
    final adjacency = <String, Set<String>>{
      for (final node in dataset.nodes) node.id: <String>{},
    };
    for (final edge in dataset.edges) {
      if (adjacency.containsKey(edge.sourceNodeId) &&
          adjacency.containsKey(edge.destinationNodeId)) {
        adjacency[edge.sourceNodeId]!.add(edge.destinationNodeId);
        adjacency[edge.destinationNodeId]!.add(edge.sourceNodeId);
      }
    }
    final visited = <String>{};
    final pending = <String>[dataset.nodes.first.id];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!visited.add(id)) continue;
      pending.addAll(adjacency[id]!.where((next) => !visited.contains(next)));
    }
    if (visited.length != dataset.nodes.length) {
      errors.add('Graph is not a single connected component.');
    }
  }

  void _footprintCrossings(CampusDataset dataset, List<String> errors) {
    final buildings = dataset.buildings.where((item) => item.footprint != null);
    final reported = <String>{};
    for (final edge in dataset.edges) {
      for (final building in buildings) {
        final footprint = building.footprint!;
        for (var index = 1; index < edge.geometry.length; index++) {
          final start = edge.geometry[index - 1];
          final end = edge.geometry[index];
          final midpoint = GeoPoint(
            lat: (start.lat + end.lat) / 2,
            lon: (start.lon + end.lon) / 2,
          );
          var crosses = pointInPolygon(midpoint, footprint);
          for (
            var boundary = 0;
            boundary < footprint.length && !crosses;
            boundary++
          ) {
            final next = footprint[(boundary + 1) % footprint.length];
            crosses = strictSegmentIntersection(
              start,
              end,
              footprint[boundary],
              next,
            );
          }
          final key = '${edge.id}:${building.id}';
          if (crosses && reported.add(key)) {
            errors.add(
              'Edge "${edge.id}" strictly crosses building "${building.id}".',
            );
          }
        }
      }
    }
  }

  void _warnings(CampusDataset dataset, List<String> warnings) {
    final aliases = <String, String>{};
    for (final building in dataset.buildings) {
      if (building.aliases.isEmpty) {
        warnings.add('Building "${building.id}" has empty aliases.');
      }
      for (final alias in building.aliases) {
        final previous = aliases[alias];
        if (previous != null && previous != building.id) {
          warnings.add('Alias "$alias" is duplicated across buildings.');
        }
        aliases[alias] = building.id;
      }
    }
    final unverified = [
      ...dataset.buildings.where((item) => !item.verified),
      ...dataset.nodes.where((item) => !item.verified),
      ...dataset.edges.where((item) => !item.verified),
    ].length;
    if (unverified > 0) warnings.add('$unverified rows are unverified.');
  }
}
