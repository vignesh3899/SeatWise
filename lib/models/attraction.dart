import 'package:equatable/equatable.dart';

import '../core/constants.dart';
import 'geo_coord.dart';

/// A point of interest discovered via OpenStreetMap Overpass along the route.
class Attraction extends Equatable {
  const Attraction({
    required this.name,
    required this.location,
    required this.category,
    this.rating,
    this.side = SeatSide.either,
    this.distanceFromRouteMeters = 0,
  });

  final String name;
  final GeoCoord location;

  /// OSM tag value, e.g. `viewpoint`, `attraction`, `castle`, `beach`.
  final String category;

  /// 0..5 heuristic score derived from OSM tags (importance, wikidata, etc.).
  final double? rating;

  /// Which side of travel this attraction falls on (filled by the engine).
  final SeatSide side;

  final double distanceFromRouteMeters;

  Attraction copyWith({SeatSide? side, double? distanceFromRouteMeters}) =>
      Attraction(
        name: name,
        location: location,
        category: category,
        rating: rating,
        side: side ?? this.side,
        distanceFromRouteMeters:
            distanceFromRouteMeters ?? this.distanceFromRouteMeters,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location.toJson(),
        'category': category,
        'rating': rating,
        'side': side.name,
        'distanceFromRouteMeters': distanceFromRouteMeters,
      };

  factory Attraction.fromJson(Map<String, dynamic> json) => Attraction(
        name: json['name'] as String,
        location: GeoCoord.fromJson(json['location'] as Map<String, dynamic>),
        category: json['category'] as String,
        rating: (json['rating'] as num?)?.toDouble(),
        side: SeatSide.values.firstWhere(
          (s) => s.name == json['side'],
          orElse: () => SeatSide.either,
        ),
        distanceFromRouteMeters:
            (json['distanceFromRouteMeters'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props =>
      [name, location, category, rating, side, distanceFromRouteMeters];
}
