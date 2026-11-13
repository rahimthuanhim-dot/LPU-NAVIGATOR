import 'building.dart';
import 'entrance.dart';
import 'graph_edge.dart';
import 'graph_node.dart';
import 'geo_point.dart';

enum DatasetKind { placeholder, surveyed }

class CampusBounds {
  const CampusBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  Map<String, double> toJson() => {
    'south': south,
    'west': west,
    'north': north,
    'east': east,
  };
}

class CampusDataset {
  const CampusDataset({
    required this.schemaVersion,
    required this.dataVersion,
    required this.builtAt,
    required this.bbox,
    required this.datasetKind,
    required this.buildings,
    required this.entrances,
    required this.nodes,
    required this.edges,
  });

  final int schemaVersion;
  final String dataVersion;
  final String builtAt;
  final CampusBounds bbox;
  final DatasetKind datasetKind;
  final List<Building> buildings;
  final List<Entrance> entrances;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  bool get isReleaseSafe =>
      datasetKind == DatasetKind.surveyed &&
      [
        ...buildings.map((item) => item.verified),
        ...nodes.map((item) => item.verified),
        ...edges.map((item) => item.verified),
      ].every((verified) => verified);

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'dataVersion': dataVersion,
    'builtAt': builtAt,
    'bbox': bbox.toJson(),
    'datasetKind': datasetKind == DatasetKind.placeholder
        ? 'PLACEHOLDER'
        : 'SURVEYED',
    'buildings': buildings.map((item) => item.toJson()).toList(),
    'entrances': entrances.map((item) => item.toJson()).toList(),
    'nodes': nodes.map((item) => item.toJson()).toList(),
    'edges': edges.map((item) => item.toJson()).toList(),
  };

  GeoPoint buildingPoint(Building building) =>
      GeoPoint(lat: building.lat, lon: building.lon);
}
