import 'package:equatable/equatable.dart';

/// Immutable latitude/longitude pair used throughout the domain layer.
///
/// Kept independent of any mapping package so models stay framework-agnostic
/// and trivially serialisable to/from Firestore and JSON APIs.
class GeoCoord extends Equatable {
  const GeoCoord({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory GeoCoord.fromJson(Map<String, dynamic> json) => GeoCoord(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  /// Parses OpenRouteService `[lng, lat]` ordering.
  factory GeoCoord.fromLngLatList(List<dynamic> pair) => GeoCoord(
        lng: (pair[0] as num).toDouble(),
        lat: (pair[1] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  List<Object?> get props => [lat, lng];

  @override
  String toString() => '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
}
