import 'dart:math' as math;

import '../models/geo_coord.dart';

/// Pure geodesy helpers used by the recommendation engine. All functions are
/// side-effect free and unit-tested. Angles are handled in degrees at the API
/// boundary and radians internally.
class Geo {
  Geo._();

  static const double earthRadiusMeters = 6371000.0;

  static double _toRad(double deg) => deg * math.pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / math.pi;

  /// Great-circle distance between two coordinates in metres (haversine).
  static double distanceMeters(GeoCoord a, GeoCoord b) {
    final dLat = _toRad(b.lat - a.lat);
    final dLng = _toRad(b.lng - a.lng);
    final lat1 = _toRad(a.lat);
    final lat2 = _toRad(b.lat);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Initial bearing (compass heading, 0..360, 0 = north) travelling from
  /// [from] to [to].
  static double bearingDegrees(GeoCoord from, GeoCoord to) {
    final lat1 = _toRad(from.lat);
    final lat2 = _toRad(to.lat);
    final dLng = _toRad(to.lng - from.lng);

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearing = _toDeg(math.atan2(y, x));
    return (bearing + 360.0) % 360.0;
  }

  /// Normalises an angle to the range [-180, 180).
  static double normalizeSignedDegrees(double deg) {
    var d = (deg + 180.0) % 360.0;
    if (d < 0) d += 360.0;
    return d - 180.0;
  }

  /// Given the vehicle [heading] and the compass bearing to a target
  /// ([targetBearing]), returns +1 if the target lies on the RIGHT of travel,
  /// -1 if on the LEFT, and 0 if roughly straight ahead/behind.
  ///
  /// Right is where the relative angle (target - heading) is in (0, 180).
  static int sideOfHeading(double heading, double targetBearing) {
    final rel = normalizeSignedDegrees(targetBearing - heading);
    if (rel.abs() < 1.0 || (180.0 - rel.abs()) < 1.0) return 0;
    return rel > 0 ? 1 : -1;
  }

  /// Perpendicular (cross-track) distance in metres of point [p] from the great
  /// circle defined by segment [a]->[b]. Always positive.
  static double crossTrackDistanceMeters(GeoCoord a, GeoCoord b, GeoCoord p) {
    final d13 = distanceMeters(a, p) / earthRadiusMeters; // angular distance
    final theta13 = _toRad(bearingDegrees(a, p));
    final theta12 = _toRad(bearingDegrees(a, b));
    final dxt = math.asin(math.sin(d13) * math.sin(theta13 - theta12));
    return (dxt * earthRadiusMeters).abs();
  }

  /// Linear interpolation between two coordinates (good enough at city/route
  /// scale for placing sample points).
  static GeoCoord lerp(GeoCoord a, GeoCoord b, double t) {
    return GeoCoord(
      lat: a.lat + (b.lat - a.lat) * t,
      lng: a.lng + (b.lng - a.lng) * t,
    );
  }
}
