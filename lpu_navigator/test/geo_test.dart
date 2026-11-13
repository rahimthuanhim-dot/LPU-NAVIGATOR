import 'package:flutter_test/flutter_test.dart';
import 'package:lpu_navigator/core/geo.dart';
import 'package:lpu_navigator/data/models/geo_point.dart';

GeoPoint p(double lat, double lon) => GeoPoint(lat: lat, lon: lon);

void main() {
  final square = [p(0, 0), p(0, 2), p(2, 2), p(2, 0)];

  test('strict intersection excludes shared endpoints and touching', () {
    expect(
      strictSegmentIntersection(p(-1, 0), p(1, 0), p(0, 0), p(0, 2)),
      isFalse,
    );
    expect(
      strictSegmentIntersection(p(-1, -1), p(0, 0), p(0, 0), p(1, 1)),
      isFalse,
    );
    expect(
      strictSegmentIntersection(p(0, 0), p(0, 2), p(0, 2), p(2, 2)),
      isFalse,
    );
  });

  test('strict intersection detects a proper crossing', () {
    expect(
      strictSegmentIntersection(p(-1, 1), p(3, 1), p(0, -1), p(0, 3)),
      isTrue,
    );
  });

  test('boundary-following segment is not inside the polygon', () {
    expect(pointInPolygon(p(0, 1), square), isFalse);
    expect(
      strictSegmentIntersection(p(0, 0), p(0, 2), p(0, 0), p(0, 2)),
      isFalse,
    );
  });

  test(
    'midpoint inside classification is available for contained segments',
    () {
      expect(pointInPolygon(p(1, 1), square), isTrue);
      expect(pointInPolygon(p(3, 1), square), isFalse);
    },
  );
}
