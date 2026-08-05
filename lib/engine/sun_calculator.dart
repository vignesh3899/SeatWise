import 'dart:math' as math;

import '../models/geo_coord.dart';

/// Position of the sun in the sky as seen from a point on the earth.
class SunPosition {
  const SunPosition({required this.azimuthDegrees, required this.altitudeDegrees});

  /// Compass azimuth, 0 = north, 90 = east, 180 = south, 270 = west.
  final double azimuthDegrees;

  /// Elevation above the horizon in degrees. Negative means the sun is down.
  final double altitudeDegrees;

  bool get isDaylight => altitudeDegrees > 0;
}

/// A dependency-free port of the well-known SunCalc algorithm
/// (https://github.com/mourner/suncalc) restricted to sun position.
///
/// The original library reports azimuth measured from south; this port converts
/// it to a compass bearing (from north, clockwise) so it composes directly with
/// the route headings produced by [Geo.bearingDegrees].
class SunCalculator {
  SunCalculator._();

  static const double _rad = math.pi / 180.0;
  static const double _obliquity = _rad * 23.4397; // Earth's axial tilt
  static const double _dayMs = 86400000.0;
  static const double _j1970 = 2440588.0;
  static const double _j2000 = 2451545.0;

  static double _toJulian(DateTime dateUtc) =>
      dateUtc.millisecondsSinceEpoch / _dayMs - 0.5 + _j1970;

  static double _toDays(DateTime dateUtc) => _toJulian(dateUtc) - _j2000;

  static double _rightAscension(double l, double b) => math.atan2(
        math.sin(l) * math.cos(_obliquity) - math.tan(b) * math.sin(_obliquity),
        math.cos(l),
      );

  static double _declination(double l, double b) => math.asin(
        math.sin(b) * math.cos(_obliquity) +
            math.cos(b) * math.sin(_obliquity) * math.sin(l),
      );

  static double _azimuthFromSouth(double h, double phi, double dec) =>
      math.atan2(
        math.sin(h),
        math.cos(h) * math.sin(phi) - math.tan(dec) * math.cos(phi),
      );

  static double _altitude(double h, double phi, double dec) => math.asin(
        math.sin(phi) * math.sin(dec) +
            math.cos(phi) * math.cos(dec) * math.cos(h),
      );

  static double _siderealTime(double d, double lw) =>
      _rad * (280.16 + 360.9856235 * d) - lw;

  static double _solarMeanAnomaly(double d) =>
      _rad * (357.5291 + 0.98560028 * d);

  static double _eclipticLongitude(double m) {
    final c = _rad *
        (1.9148 * math.sin(m) +
            0.02 * math.sin(2 * m) +
            0.0003 * math.sin(3 * m));
    const perihelion = _rad * 102.9372;
    return m + c + perihelion + math.pi;
  }

  /// Returns the sun's [SunPosition] at [dateUtc] as seen from [coord].
  static SunPosition position(DateTime dateUtc, GeoCoord coord) {
    final lw = _rad * -coord.lng;
    final phi = _rad * coord.lat;
    final d = _toDays(dateUtc.toUtc());

    final m = _solarMeanAnomaly(d);
    final l = _eclipticLongitude(m);
    final dec = _declination(l, 0);
    final ra = _rightAscension(l, 0);

    final h = _siderealTime(d, lw) - ra;

    final azimuthSouth = _azimuthFromSouth(h, phi, dec);
    final altitude = _altitude(h, phi, dec);

    // Convert "from south" (0 = south) to compass bearing (0 = north).
    var compass = (azimuthSouth / _rad) + 180.0;
    compass %= 360.0;
    if (compass < 0) compass += 360.0;

    return SunPosition(
      azimuthDegrees: compass,
      altitudeDegrees: altitude / _rad,
    );
  }
}
