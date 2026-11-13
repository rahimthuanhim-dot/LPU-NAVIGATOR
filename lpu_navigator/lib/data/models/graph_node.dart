import 'geo_point.dart';

enum GraphNodeType { junction, entrance, endpoint, poi }

class GraphNode {
  const GraphNode({
    required this.id,
    required this.lat,
    required this.lon,
    required this.nodeType,
    required this.source,
    required this.verified,
  });

  final String id;
  final double lat;
  final double lon;
  final GraphNodeType nodeType;
  final String source;
  final bool verified;

  GeoPoint get point => GeoPoint(lat: lat, lon: lon);

  factory GraphNode.fromJson(Map<String, dynamic> json, String path) {
    final id = json['id'];
    final lat = json['lat'];
    final lon = json['lon'];
    final type = json['nodeType'];
    final source = json['source'];
    final verified = json['verified'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id is required');
    }
    if (lat is! num) throw FormatException('$path.lat must be a number');
    if (lon is! num) throw FormatException('$path.lon must be a number');
    if (type is! String) throw FormatException('$path.nodeType is required');
    final nodeType = _parseNodeType(type, '$path.nodeType');
    if (source is! String || source.isEmpty) {
      throw FormatException('$path.source is required');
    }
    if (verified is! bool) {
      throw FormatException('$path.verified must be boolean');
    }
    return GraphNode(
      id: id,
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      nodeType: nodeType,
      source: source,
      verified: verified,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': lat,
    'lon': lon,
    'nodeType': nodeType.name,
    'source': source,
    'verified': verified,
  };
}

GraphNodeType _parseNodeType(String value, String path) {
  for (final type in GraphNodeType.values) {
    if (type.name == value) return type;
  }
  throw FormatException('$path must be junction, entrance, endpoint, or poi');
}
