class GeoPoint {
  const GeoPoint({required this.lat, required this.lon});

  final double lat;
  final double lon;

  factory GeoPoint.fromJson(Object? value, String path) {
    if (value is! Map) {
      throw FormatException('$path must be an object');
    }
    final lat = value['lat'];
    final lon = value['lon'];
    if (lat is! num) throw FormatException('$path.lat must be a number');
    if (lon is! num) throw FormatException('$path.lon must be a number');
    return GeoPoint(lat: lat.toDouble(), lon: lon.toDouble());
  }

  Map<String, double> toJson() => {'lat': lat, 'lon': lon};
}
