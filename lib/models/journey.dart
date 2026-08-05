import 'package:equatable/equatable.dart';

import '../core/constants.dart';
import 'geo_coord.dart';
import 'seat_recommendation.dart';

/// A saved journey: where the user was going and what SeatWise recommended.
/// Persisted in the `journeys` Firestore collection.
class Journey extends Equatable {
  const Journey({
    required this.id,
    required this.userId,
    required this.originLabel,
    required this.destinationLabel,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.createdAt,
    required this.recommendedSide,
    required this.headline,
    required this.etaSeconds,
    this.recommendation,
  });

  final String id;
  final String userId;
  final String originLabel;
  final String destinationLabel;
  final GeoCoord origin;
  final GeoCoord destination;
  final DateTime departureAt;
  final DateTime createdAt;

  /// Denormalised summary fields for cheap history-list rendering.
  final SeatSide recommendedSide;
  final String headline;
  final double etaSeconds;

  /// Full recommendation payload (optional; hydrated when opening details).
  final SeatRecommendation? recommendation;

  Duration get eta => Duration(seconds: etaSeconds.round());

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'originLabel': originLabel,
        'destinationLabel': destinationLabel,
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'departureAt': departureAt.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'recommendedSide': recommendedSide.name,
        'headline': headline,
        'etaSeconds': etaSeconds,
        'recommendation': recommendation?.toJson(),
      };

  factory Journey.fromJson(String id, Map<String, dynamic> json) => Journey(
        id: id,
        userId: json['userId'] as String,
        originLabel: json['originLabel'] as String? ?? 'Origin',
        destinationLabel: json['destinationLabel'] as String? ?? 'Destination',
        origin: GeoCoord.fromJson(json['origin'] as Map<String, dynamic>),
        destination:
            GeoCoord.fromJson(json['destination'] as Map<String, dynamic>),
        departureAt: DateTime.tryParse(json['departureAt'].toString())
                ?.toLocal() ??
            DateTime.now(),
        createdAt:
            DateTime.tryParse(json['createdAt'].toString())?.toLocal() ??
                DateTime.now(),
        recommendedSide: SeatSide.values.firstWhere(
          (s) => s.name == json['recommendedSide'],
          orElse: () => SeatSide.either,
        ),
        headline: json['headline'] as String? ?? '',
        etaSeconds: (json['etaSeconds'] as num?)?.toDouble() ?? 0,
        recommendation: json['recommendation'] != null
            ? SeatRecommendation.fromJson(
                json['recommendation'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [id, userId, createdAt, recommendedSide, headline];
}
