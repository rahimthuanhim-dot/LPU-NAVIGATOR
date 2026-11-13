import 'dart:math' as math;

import '../data/models/geo_point.dart';

const _earthRadiusMeters = 6371000.0;

double haversineDistance(GeoPoint a, GeoPoint b) {
  final lat1 = a.lat * math.pi / 180;
  final lat2 = b.lat * math.pi / 180;
  final dLat = (b.lat - a.lat) * math.pi / 180;
  final dLon = (b.lon - a.lon) * math.pi / 180;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(h.toDouble()));
}

double polylineLength(List<GeoPoint> points) {
  var total = 0.0;
  for (var index = 1; index < points.length; index++) {
    total += haversineDistance(points[index - 1], points[index]);
  }
  return total;
}

bool pointInPolygon(GeoPoint point, List<GeoPoint> polygon) {
  var inside = false;
  for (var index = 0; index < polygon.length; index++) {
    final a = polygon[index];
    final b = polygon[(index + 1) % polygon.length];
    if (_onSegment(a, b, point)) return false;
    if ((a.lon > point.lon) != (b.lon > point.lon)) {
      final latitude =
          (b.lat - a.lat) * (point.lon - a.lon) / (b.lon - a.lon) + a.lat;
      if (point.lat < latitude) inside = !inside;
    }
  }
  return inside;
}

bool strictSegmentIntersection(GeoPoint a, GeoPoint b, GeoPoint c, GeoPoint d) {
  final abC = _orientation(a, b, c);
  final abD = _orientation(a, b, d);
  final cdA = _orientation(c, d, a);
  final cdB = _orientation(c, d, b);
  return abC * abD < 0 && cdA * cdB < 0;
}

double _orientation(GeoPoint a, GeoPoint b, GeoPoint c) =>
    (b.lat - a.lat) * (c.lon - a.lon) - (b.lon - a.lon) * (c.lat - a.lat);

bool _onSegment(GeoPoint a, GeoPoint b, GeoPoint point) {
  const epsilon = 1e-10;
  if (_orientation(a, b, point).abs() > epsilon) return false;
  return point.lat >= math.min(a.lat, b.lat) - epsilon &&
      point.lat <= math.max(a.lat, b.lat) + epsilon &&
      point.lon >= math.min(a.lon, b.lon) - epsilon &&
      point.lon <= math.max(a.lon, b.lon) + epsilon;
}
