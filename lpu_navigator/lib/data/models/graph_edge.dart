import 'geo_point.dart';

class GraphEdge {
  const GraphEdge({
    required this.id,
    required this.sourceNodeId,
    required this.destinationNodeId,
    required this.distanceMeters,
    required this.pathwayType,
    required this.isAccessible,
    required this.isRestricted,
    required this.oneway,
    required this.geometry,
    required this.source,
    required this.verified,
  });

  final String id;
  final String sourceNodeId;
  final String destinationNodeId;
  final double distanceMeters;
  final String pathwayType;
  final bool isAccessible;
  final bool isRestricted;
  final bool oneway;
  final List<GeoPoint> geometry;
  final String source;
  final bool verified;

  factory GraphEdge.fromJson(Map<String, dynamic> json, String path) {
    final id = json['id'];
    final sourceNodeId = json['sourceNodeId'];
    final destinationNodeId = json['destinationNodeId'];
    final distanceMeters = json['distanceMeters'];
    final pathwayType = json['pathwayType'];
    final isAccessible = json['isAccessible'];
    final isRestricted = json['isRestricted'];
    final oneway = json['oneway'];
    final rawGeometry = json['geometry'];
    final source = json['source'];
    final verified = json['verified'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id is required');
    }
    if (sourceNodeId is! String || sourceNodeId.isEmpty) {
      throw FormatException('$path.sourceNodeId is required');
    }
    if (destinationNodeId is! String || destinationNodeId.isEmpty) {
      throw FormatException('$path.destinationNodeId is required');
    }
    if (distanceMeters is! num) {
      throw FormatException('$path.distanceMeters must be a number');
    }
    if (pathwayType is! String || pathwayType.isEmpty) {
      throw FormatException('$path.pathwayType is required');
    }
    if (isAccessible is! bool) {
      throw FormatException('$path.isAccessible must be boolean');
    }
    if (isRestricted is! bool) {
      throw FormatException('$path.isRestricted must be boolean');
    }
    if (oneway is! bool) throw FormatException('$path.oneway must be boolean');
    if (rawGeometry is! List || rawGeometry.length < 2) {
      throw FormatException('$path.geometry must contain at least two points');
    }
    if (source is! String || source.isEmpty) {
      throw FormatException('$path.source is required');
    }
    if (verified is! bool) {
      throw FormatException('$path.verified must be boolean');
    }
    return GraphEdge(
      id: id,
      sourceNodeId: sourceNodeId,
      destinationNodeId: destinationNodeId,
      distanceMeters: distanceMeters.toDouble(),
      pathwayType: pathwayType,
      isAccessible: isAccessible,
      isRestricted: isRestricted,
      oneway: oneway,
      geometry: List.unmodifiable(
        rawGeometry.map(
          (item) => GeoPoint.fromJson(
            item,
            '$path.geometry[${rawGeometry.indexOf(item)}]',
          ),
        ),
      ),
      source: source,
      verified: verified,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceNodeId': sourceNodeId,
    'destinationNodeId': destinationNodeId,
    'distanceMeters': distanceMeters,
    'pathwayType': pathwayType,
    'isAccessible': isAccessible,
    'isRestricted': isRestricted,
    'oneway': oneway,
    'geometry': geometry.map((point) => point.toJson()).toList(),
    'source': source,
    'verified': verified,
  };
}
