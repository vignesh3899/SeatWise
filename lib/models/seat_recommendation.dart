import 'package:equatable/equatable.dart';

import '../core/constants.dart';
import 'attraction.dart';
import 'weather_point.dart';

/// The per-side breakdown of scores. All sub-scores are on a 0..100 scale where
/// higher is better for the passenger sitting on that side.
class SideScores extends Equatable {
  const SideScores({
    required this.comfort,
    required this.scenic,
    required this.weather,
    required this.total,
  });

  final double comfort; // higher = more shade / less harsh sun
  final double scenic; // higher = more/better attractions on this side
  final double weather; // higher = more pleasant weather-driven comfort
  final double total; // weighted blend

  Map<String, dynamic> toJson() => {
        'comfort': comfort,
        'scenic': scenic,
        'weather': weather,
        'total': total,
      };

  factory SideScores.fromJson(Map<String, dynamic> json) => SideScores(
        comfort: (json['comfort'] as num).toDouble(),
        scenic: (json['scenic'] as num).toDouble(),
        weather: (json['weather'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [comfort, scenic, weather, total];
}

/// The full output of the recommendation engine.
class SeatRecommendation extends Equatable {
  const SeatRecommendation({
    required this.recommendedSide,
    required this.confidence,
    required this.leftScores,
    required this.rightScores,
    required this.headline,
    required this.reasons,
    required this.etaSeconds,
    required this.crowdLevel,
    required this.attractions,
    required this.weatherSamples,
    required this.sunOnRightFraction,
  });

  final SeatSide recommendedSide;

  /// 0..1, how decisive the recommendation is (derived from the score gap).
  final double confidence;

  final SideScores leftScores;
  final SideScores rightScores;

  /// One-line summary, e.g. "Sit on the LEFT for shade and better views".
  final String headline;

  /// Ordered, human-readable justification bullets.
  final List<String> reasons;

  final double etaSeconds;

  /// Estimated crowd level 0..1 (0 = empty, 1 = packed).
  final double crowdLevel;

  final List<Attraction> attractions;
  final List<WeatherPoint> weatherSamples;

  /// Fraction of the journey (0..1) for which the sun falls on the right side.
  final double sunOnRightFraction;

  Duration get eta => Duration(seconds: etaSeconds.round());

  String get crowdLabel {
    if (crowdLevel < 0.34) return 'Light';
    if (crowdLevel < 0.67) return 'Moderate';
    return 'Busy';
  }

  Map<String, dynamic> toJson() => {
        'recommendedSide': recommendedSide.name,
        'confidence': confidence,
        'leftScores': leftScores.toJson(),
        'rightScores': rightScores.toJson(),
        'headline': headline,
        'reasons': reasons,
        'etaSeconds': etaSeconds,
        'crowdLevel': crowdLevel,
        'sunOnRightFraction': sunOnRightFraction,
        'attractions': attractions.map((a) => a.toJson()).toList(),
        'weatherSamples': weatherSamples.map((w) => w.toJson()).toList(),
      };

  factory SeatRecommendation.fromJson(Map<String, dynamic> json) =>
      SeatRecommendation(
        recommendedSide: SeatSide.values.firstWhere(
          (s) => s.name == json['recommendedSide'],
          orElse: () => SeatSide.either,
        ),
        confidence: (json['confidence'] as num).toDouble(),
        leftScores:
            SideScores.fromJson(json['leftScores'] as Map<String, dynamic>),
        rightScores:
            SideScores.fromJson(json['rightScores'] as Map<String, dynamic>),
        headline: json['headline'] as String,
        reasons: (json['reasons'] as List<dynamic>).cast<String>(),
        etaSeconds: (json['etaSeconds'] as num).toDouble(),
        crowdLevel: (json['crowdLevel'] as num).toDouble(),
        sunOnRightFraction: (json['sunOnRightFraction'] as num?)?.toDouble() ?? 0.5,
        attractions: (json['attractions'] as List<dynamic>? ?? [])
            .map((a) => Attraction.fromJson(a as Map<String, dynamic>))
            .toList(),
        weatherSamples: (json['weatherSamples'] as List<dynamic>? ?? [])
            .map((w) => WeatherPoint.fromJson(w as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [
        recommendedSide,
        confidence,
        leftScores,
        rightScores,
        headline,
        reasons,
        etaSeconds,
        crowdLevel,
        sunOnRightFraction,
      ];
}
