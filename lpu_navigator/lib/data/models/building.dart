import 'geo_point.dart';

class Building {
  const Building({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
    required this.aliases,
    required this.footprint,
    required this.source,
    required this.verified,
  });

  final String id;
  final String name;
  final String category;
  final double lat;
  final double lon;
  final List<String> aliases;
  final List<GeoPoint>? footprint;
  final String source;
  final bool verified;

  factory Building.fromJson(Map<String, dynamic> json, String path) {
    return Building(
      id: _string(json, 'id', path),
      name: _string(json, 'name', path),
      category: _string(json, 'category', path),
      lat: _number(json, 'lat', path),
      lon: _number(json, 'lon', path),
      aliases: _strings(json, 'aliases', path),
      footprint: _points(json['footprint'], '$path.footprint'),
      source: _string(json, 'source', path),
      verified: _bool(json, 'verified', path),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'lat': lat,
    'lon': lon,
    'aliases': aliases,
    if (footprint != null)
      'footprint': footprint!.map((point) => point.toJson()).toList(),
    'source': source,
    'verified': verified,
  };
}

String _string(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$path.$key must be a non-empty string');
  }
  return value;
}

double _number(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! num) throw FormatException('$path.$key must be a number');
  return value.toDouble();
}

bool _bool(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! bool) throw FormatException('$path.$key must be a boolean');
  return value;
}

List<String> _strings(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$path.$key must be a string array');
  }
  return List.unmodifiable(value.cast<String>());
}

List<GeoPoint>? _points(Object? value, String path) {
  if (value == null) return null;
  if (value is! List) throw FormatException('$path must be an array');
  return List.unmodifiable(
    value.map(
      (item) => GeoPoint.fromJson(item, '$path[${value.indexOf(item)}]'),
    ),
  );
}
