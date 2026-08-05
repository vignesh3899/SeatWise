import 'package:equatable/equatable.dart';

import 'geo_coord.dart';

/// A single analysed piece of the route. The engine samples the polyline into
/// roughly equal-length segments and reasons about each one independently
/// (sun side, weather, scenery) before aggregating.
class RouteSegment extends Equatable {
  const RouteSegment({
    required this.start,
    required this.end,
    required this.headingDegrees,
    required this.lengthMeters,
    required this.cumulativeSeconds,
  });

  final GeoCoord start;
  final GeoCoord end;

  /// Compass heading of travel along this segment (0..360).
  final double headingDegrees;

  /// Segment length in metres.
  final double lengthMeters;

  /// Seconds from departure until the vehicle reaches the segment midpoint.
  final double cumulativeSeconds;

  /// Midpoint used for sampling weather, sun and attractions.
  GeoCoord get midpoint => GeoCoord(
        lat: (start.lat + end.lat) / 2,
        lng: (start.lng + end.lng) / 2,
      );

  @override
  List<Object?> get props =>
      [start, end, headingDegrees, lengthMeters, cumulativeSeconds];
}
