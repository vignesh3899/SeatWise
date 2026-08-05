import 'dart:math' as math;

import '../core/constants.dart';
import '../core/geo.dart';
import '../models/geo_coord.dart';
import '../models/route_data.dart';
import '../models/route_segment.dart';

/// Turns a raw directions polyline into a list of evenly-weighted
/// [RouteSegment]s that the engine can reason about one at a time.
///
/// Rather than analyse every one of the (often thousands of) polyline vertices,
/// we merge consecutive points until each segment is about
/// [AppConstants.segmentSampleMeters] long. This keeps the engine fast and the
/// number of weather API calls small, while preserving heading changes.
class RouteSampler {
  const RouteSampler();

  List<RouteSegment> sample(RouteData route) {
    final points = route.polyline;
    if (points.length < 2) return const [];

    // Average speed (m/s) used to estimate the clock time at each segment so
    // the sun position is computed for when the bus is actually there.
    final avgSpeed = route.durationSeconds > 0
        ? route.distanceMeters / route.durationSeconds
        : 12.0; // ~43 km/h fallback

    final segments = <RouteSegment>[];
    var anchor = points.first;
    var accumulated = 0.0; // metres since the last emitted segment
    var travelled = 0.0; // metres from the very start

    for (var i = 1; i < points.length; i++) {
      final current = points[i];
      final step = Geo.distanceMeters(points[i - 1], current);
      accumulated += step;
      travelled += step;

      final isLast = i == points.length - 1;
      if (accumulated >= AppConstants.segmentSampleMeters || isLast) {
        final midTravelled = travelled - accumulated / 2;
        segments.add(
          RouteSegment(
            start: anchor,
            end: current,
            headingDegrees: Geo.bearingDegrees(anchor, current),
            lengthMeters: accumulated,
            cumulativeSeconds: avgSpeed > 0 ? midTravelled / avgSpeed : 0,
          ),
        );
        anchor = current;
        accumulated = 0.0;
      }
    }
    return segments;
  }

  /// Axis-aligned bounding box `(south, west, north, east)` enclosing the route,
  /// padded by [padMeters] so attractions just off the ends are still found.
  ({double south, double west, double north, double east}) boundingBox(
    List<GeoCoord> points, {
    double padMeters = 1500,
  }) {
    var south = points.first.lat;
    var north = points.first.lat;
    var west = points.first.lng;
    var east = points.first.lng;

    for (final p in points) {
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lng);
      east = math.max(east, p.lng);
    }

    // Rough degree padding (1 deg latitude ~= 111 km).
    final padLat = padMeters / 111000.0;
    final midLatRad = ((south + north) / 2) * (math.pi / 180.0);
    final cosLat = math.max(0.05, math.cos(midLatRad).abs());
    final padLng = padMeters / (111000.0 * cosLat);

    return (
      south: south - padLat,
      west: west - padLng,
      north: north + padLat,
      east: east + padLng,
    );
  }
}
