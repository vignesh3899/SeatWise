import 'package:flutter_test/flutter_test.dart';
import 'package:seatwise/core/geo.dart';
import 'package:seatwise/models/geo_coord.dart';

void main() {
  group('Geo.distanceMeters', () {
    test('roughly one degree of latitude is ~111 km', () {
      final d = Geo.distanceMeters(
        const GeoCoord(lat: 0, lng: 0),
        const GeoCoord(lat: 1, lng: 0),
      );
      expect(d, closeTo(111195, 500));
    });

    test('same point is zero', () {
      expect(
        Geo.distanceMeters(
          const GeoCoord(lat: 12.9, lng: 77.6),
          const GeoCoord(lat: 12.9, lng: 77.6),
        ),
        0,
      );
    });
  });

  group('Geo.bearingDegrees', () {
    test('due north is ~0 degrees', () {
      final b = Geo.bearingDegrees(
        const GeoCoord(lat: 0, lng: 0),
        const GeoCoord(lat: 1, lng: 0),
      );
      expect(b, anyOf(closeTo(0, 1), closeTo(360, 1)));
    });

    test('due east is ~90 degrees', () {
      final b = Geo.bearingDegrees(
        const GeoCoord(lat: 0, lng: 0),
        const GeoCoord(lat: 0, lng: 1),
      );
      expect(b, closeTo(90, 1));
    });
  });

  group('Geo.sideOfHeading', () {
    test('target to the right of an east heading', () {
      // Heading east (90), sun to the south (180) -> on the right (+1).
      expect(Geo.sideOfHeading(90, 180), 1);
    });

    test('target to the left of an east heading', () {
      // Heading east (90), target to the north (0) -> on the left (-1).
      expect(Geo.sideOfHeading(90, 0), -1);
    });

    test('straight ahead is zero', () {
      expect(Geo.sideOfHeading(90, 90), 0);
    });
  });

  test('normalizeSignedDegrees wraps into [-180, 180)', () {
    expect(Geo.normalizeSignedDegrees(190), closeTo(-170, 1e-9));
    expect(Geo.normalizeSignedDegrees(-190), closeTo(170, 1e-9));
    expect(Geo.normalizeSignedDegrees(45), closeTo(45, 1e-9));
  });
}
