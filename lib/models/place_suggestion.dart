import 'package:equatable/equatable.dart';

import 'geo_coord.dart';

/// A geocoding suggestion returned by Nominatim when the user searches for an
/// origin or destination.
class PlaceSuggestion extends Equatable {
  const PlaceSuggestion({
    required this.displayName,
    required this.coord,
  });

  final String displayName;
  final GeoCoord coord;

  /// Short label (first comma-separated component) for compact display.
  String get shortName => displayName.split(',').first.trim();

  factory PlaceSuggestion.fromNominatimJson(Map<String, dynamic> json) =>
      PlaceSuggestion(
        displayName: json['display_name'] as String? ?? 'Unknown place',
        coord: GeoCoord(
          lat: double.parse(json['lat'].toString()),
          lng: double.parse(json['lon'].toString()),
        ),
      );

  @override
  List<Object?> get props => [displayName, coord];
}
