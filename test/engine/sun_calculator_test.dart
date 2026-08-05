import 'package:flutter_test/flutter_test.dart';
import 'package:seatwise/engine/sun_calculator.dart';
import 'package:seatwise/models/geo_coord.dart';

void main() {
  // A point on the Greenwich meridian so local solar noon ~= 12:00 UTC.
  const place = GeoCoord(lat: 40, lng: 0);

  test('sun is high and roughly south at local noon (N hemisphere summer)', () {
    final pos = SunCalculator.position(
      DateTime.utc(2024, 6, 21, 12, 0),
      place,
    );
    expect(pos.isDaylight, isTrue);
    expect(pos.altitudeDegrees, greaterThan(40));
    // Azimuth should be near due south (180), allowing generous tolerance.
    expect(pos.azimuthDegrees, closeTo(180, 30));
  });

  test('sun is below the horizon at local midnight', () {
    final pos = SunCalculator.position(
      DateTime.utc(2024, 6, 21, 0, 0),
      place,
    );
    expect(pos.altitudeDegrees, lessThan(0));
    expect(pos.isDaylight, isFalse);
  });

  test('morning sun sits in the eastern half of the sky', () {
    final pos = SunCalculator.position(
      DateTime.utc(2024, 3, 21, 7, 0),
      place,
    );
    // Eastern azimuths are between north (0/360) and south (180).
    expect(pos.azimuthDegrees, inInclusiveRange(60, 160));
  });
}
