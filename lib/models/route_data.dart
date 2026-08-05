import 'package:equatable/equatable.dart';

import 'geo_coord.dart';

/// Result of a directions request: the full polyline plus summary metrics.
class RouteData extends Equatable {
  const RouteData({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Ordered coordinates describing the driven path.
  final List<GeoCoord> polyline;

  final double distanceMeters;
  final double durationSeconds;

  double get distanceKm => distanceMeters / 1000.0;
  Duration get duration => Duration(seconds: durationSeconds.round());

  factory RouteData.fromOrsJson(Map<String, dynamic> json) {
    final features = json['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw const FormatException('OpenRouteService returned no route.');
    }
    final feature = features.first as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List<dynamic>)
        .map((c) => GeoCoord.fromLngLatList(c as List<dynamic>))
        .toList(growable: false);

    final summary = ((feature['properties'] as Map<String, dynamic>)['summary']
        as Map<String, dynamic>);

    return RouteData(
      polyline: coords,
      distanceMeters: (summary['distance'] as num).toDouble(),
      durationSeconds: (summary['duration'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [polyline, distanceMeters, durationSeconds];
}
