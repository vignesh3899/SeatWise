import 'dart:math' as math;

import '../core/constants.dart';
import '../core/geo.dart';
import '../models/attraction.dart';
import '../models/route_segment.dart';
import '../models/seat_recommendation.dart';
import '../models/weather_point.dart';
import '../utils/formatters.dart';
import 'sun_calculator.dart';

class RecommendationInput {
  const RecommendationInput({
    required this.segments,
    required this.departure,
    required this.weatherSamples,
    required this.attractions,
    required this.distanceMeters,
    required this.durationSeconds,
    this.preferShade = true,
  });

  final List<RouteSegment> segments;
  final DateTime departure;
  final List<WeatherPoint> weatherSamples;
  final List<Attraction> attractions;
  final double distanceMeters;
  final double durationSeconds;
  final bool preferShade;
}

class SeatEngine {
  const SeatEngine();

  SeatRecommendation recommend(RecommendationInput input) {
    final segments = input.segments;

    if (segments.isEmpty) {
      return _neutral(input, 'We could not read the route geometry.');
    }

    // ============================================================
    // 1. SUN / SHADE ANALYSIS
    // ============================================================

    var leftSunLoad = 0.0;
    var rightSunLoad = 0.0;
    var daylightWeight = 0.0;
    var totalWeight = 0.0;
    var sunOnRightWeight = 0.0;

    for (final seg in segments) {
      final weight = math.max(seg.lengthMeters, 1.0);
      totalWeight += weight;

      final time = input.departure.add(
        Duration(seconds: seg.cumulativeSeconds.round()),
      );

      final sun = SunCalculator.position(
        time.toUtc(),
        seg.midpoint,
      );

      if (!sun.isDaylight) continue;

      final weather = _weatherForSegment(
        input,
        seg,
        segments,
      );

      final clearness = weather?.clearness ?? 0.8;

      final altitudeRadians =
          sun.altitudeDegrees * math.pi / 180.0;

      final illumination =
          math.max(0.0, math.sin(altitudeRadians));

      final laterality =
          math.cos(altitudeRadians).abs();

      final relativeAngle = Geo.normalizeSignedDegrees(
        sun.azimuthDegrees - seg.headingDegrees,
      );

      final perpendicular =
          math.sin(relativeAngle * math.pi / 180.0).abs();

      final load = weight *
          illumination *
          (0.35 + 0.65 * laterality) *
          perpendicular *
          clearness;

      daylightWeight += weight * illumination;

      final side = Geo.sideOfHeading(
        seg.headingDegrees,
        sun.azimuthDegrees,
      );

      if (side > 0) {
        rightSunLoad += load;
        sunOnRightWeight += weight;
      } else if (side < 0) {
        leftSunLoad += load;
      }
    }

    final sunOnRightFraction = totalWeight > 0
        ? (sunOnRightWeight / totalWeight).clamp(0.0, 1.0)
        : 0.5;

    final totalSunLoad =
        leftSunLoad + rightSunLoad;

    final isDaylightTrip =
        daylightWeight > totalWeight * 0.05;

    // ============================================================
    // 2. COMFORT SCORE
    // ============================================================

    double comfortLeft;
    double comfortRight;

    if (!isDaylightTrip || totalSunLoad < 1e-6) {
      comfortLeft = 50.0;
      comfortRight = 50.0;
    } else {
      final leftSunShare =
          leftSunLoad / totalSunLoad;

      final rightSunShare =
          rightSunLoad / totalSunLoad;

      if (input.preferShade) {
        comfortLeft =
            100.0 * rightSunShare;

        comfortRight =
            100.0 * leftSunShare;
      } else {
        comfortLeft =
            100.0 * leftSunShare;

        comfortRight =
            100.0 * rightSunShare;
      }
    }

    // ============================================================
    // 3. SCENIC SCORE
    // ============================================================

    final sidedAttractions =
        _assignSides(input.attractions, segments);

    var scenicLeftRaw = 0.0;
    var scenicRightRaw = 0.0;

    for (final attraction in sidedAttractions) {
      final proximity = (
        1.0 -
        (attraction.distanceFromRouteMeters /
                AppConstants.attractionSearchRadiusMeters)
      ).clamp(0.0, 1.0);

      final value =
          (attraction.rating ?? 2.5) *
          (0.4 + 0.6 * proximity);

      if (attraction.side == SeatSide.left) {
        scenicLeftRaw += value;
      } else if (attraction.side == SeatSide.right) {
        scenicRightRaw += value;
      }
    }

    final scenicTotal =
        scenicLeftRaw + scenicRightRaw;

    final scenicLeft = scenicTotal < 1e-6
        ? 50.0
        : 100.0 * scenicLeftRaw / scenicTotal;

    final scenicRight = scenicTotal < 1e-6
        ? 50.0
        : 100.0 * scenicRightRaw / scenicTotal;

    // ============================================================
    // 4. WEATHER SCORE
    // ============================================================

    final weatherPair = _weatherScores(
      input,
      leftIsShade: leftSunLoad <= rightSunLoad,
      isDaylightTrip: isDaylightTrip,
    );

    // ============================================================
    // 5. FINAL SCORES
    // ============================================================

    final leftTotal = _blend(
      comfortLeft,
      scenicLeft,
      weatherPair.left,
    );

    final rightTotal = _blend(
      comfortRight,
      scenicRight,
      weatherPair.right,
    );

    final left = SideScores(
      comfort: comfortLeft,
      scenic: scenicLeft,
      weather: weatherPair.left,
      total: leftTotal,
    );

    final right = SideScores(
      comfort: comfortRight,
      scenic: scenicRight,
      weather: weatherPair.right,
      total: rightTotal,
    );

    // ============================================================
    // 6. RECOMMENDATION
    // ============================================================

    final gap =
        (leftTotal - rightTotal).abs();

    final maxScore =
        math.max(leftTotal, rightTotal);

    final minScore =
        math.min(leftTotal, rightTotal);

    final relativeGap = maxScore > 0
        ? gap / maxScore
        : 0.0;

    SeatSide recommendedSide;

    if (gap < AppConstants.tieThreshold) {
      recommendedSide = SeatSide.either;
    } else if (leftTotal > rightTotal) {
      recommendedSide = SeatSide.left;
    } else {
      recommendedSide = SeatSide.right;
    }

    // Confidence is based on the actual score separation.
    double confidence;

    if (recommendedSide == SeatSide.either) {
      confidence = 0.10 + (relativeGap * 0.40);
    } else {
      confidence = 0.50 + (relativeGap * 0.50);
    }

    confidence = confidence.clamp(0.0, 1.0);

    // ============================================================
    // 7. CROWD
    // ============================================================

    final crowd = _estimateCrowd(
      input.departure,
      input.distanceMeters,
    );

    // ============================================================
    // 8. EXPLANATIONS
    // ============================================================

    final reasons = _buildReasons(
      side: recommendedSide,
      input: input,
      left: left,
      right: right,
      sunOnRightFraction: sunOnRightFraction,
      isDaylightTrip: isDaylightTrip,
      attractions: sidedAttractions,
      crowd: crowd,
    );

    return SeatRecommendation(
      recommendedSide: recommendedSide,
      confidence: confidence,
      leftScores: left,
      rightScores: right,
      headline: _headline(recommendedSide),
      reasons: reasons,
      etaSeconds: input.durationSeconds,
      crowdLevel: crowd,
      attractions: sidedAttractions,
      weatherSamples: input.weatherSamples,
      sunOnRightFraction: sunOnRightFraction,
    );
  }

  // ============================================================
  // SCORE BLENDING
  // ============================================================

  double _blend(
    double comfort,
    double scenic,
    double weather,
  ) {
    return (
      AppConstants.weightComfort * comfort +
      AppConstants.weightScenic * scenic +
      AppConstants.weightWeather * weather
    ).clamp(0.0, 100.0);
  }

  // ============================================================
  // WEATHER
  // ============================================================

  WeatherPoint? _weatherForSegment(
    RecommendationInput input,
    RouteSegment seg,
    List<RouteSegment> segments,
  ) {
    if (input.weatherSamples.isEmpty) {
      return null;
    }

    final index = segments.indexOf(seg);

    final fraction = segments.length > 1
        ? index / (segments.length - 1)
        : 0.0;

    final sampleIndex =
        (fraction * (input.weatherSamples.length - 1))
            .round()
            .clamp(
              0,
              input.weatherSamples.length - 1,
            );

    return input.weatherSamples[sampleIndex];
  }

  ({double left, double right}) _weatherScores(
    RecommendationInput input, {
    required bool leftIsShade,
    required bool isDaylightTrip,
  }) {
    if (input.weatherSamples.isEmpty ||
        !isDaylightTrip) {
      return (
        left: 50.0,
        right: 50.0,
      );
    }

    final avgTemp =
        input.weatherSamples
                .map((w) => w.temperatureC)
                .reduce((a, b) => a + b) /
            input.weatherSamples.length;

    final avgClearness =
        input.weatherSamples
                .map((w) => w.clearness)
                .reduce((a, b) => a + b) /
            input.weatherSamples.length;

    final heatFactor =
        ((avgTemp - 22.0) / 13.0)
            .clamp(0.0, 1.0);

    final advantage =
        heatFactor *
        avgClearness *
        25.0;

    if (!input.preferShade) {
      final left =
          leftIsShade
              ? 50.0 - advantage
              : 50.0 + advantage;

      return (
        left: left.clamp(0.0, 100.0),
        right: (100.0 - left)
            .clamp(0.0, 100.0),
      );
    }

    final left =
        leftIsShade
            ? 50.0 + advantage
            : 50.0 - advantage;

    return (
      left: left.clamp(0.0, 100.0),
      right: (100.0 - left)
          .clamp(0.0, 100.0),
    );
  }

  // ============================================================
  // ATTRACTIONS
  // ============================================================

  List<Attraction> _assignSides(
    List<Attraction> attractions,
    List<RouteSegment> segments,
  ) {
    final result = <Attraction>[];

    for (final attraction in attractions) {
      RouteSegment? nearest;
      var nearestDistance = double.infinity;

      for (final seg in segments) {
        final distance =
            Geo.crossTrackDistanceMeters(
          seg.start,
          seg.end,
          attraction.location,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = seg;
        }
      }

      if (nearest == null) {
        continue;
      }

      final bearingToAttraction =
          Geo.bearingDegrees(
        nearest.midpoint,
        attraction.location,
      );

      final sideSign =
          Geo.sideOfHeading(
        nearest.headingDegrees,
        bearingToAttraction,
      );

      final side = sideSign > 0
          ? SeatSide.right
          : sideSign < 0
              ? SeatSide.left
              : SeatSide.either;

      result.add(
        attraction.copyWith(
          side: side,
          distanceFromRouteMeters:
              nearestDistance,
        ),
      );
    }

    result.sort(
      (a, b) =>
          (b.rating ?? 0)
              .compareTo(a.rating ?? 0),
    );

    return result
        .where(
          (a) =>
              a.distanceFromRouteMeters <=
              AppConstants.attractionSearchRadiusMeters,
        )
        .toList();
  }

  // ============================================================
  // CROWD
  // ============================================================

  double _estimateCrowd(
    DateTime departure,
    double distanceMeters,
  ) {
    final hour = departure.hour;

    double base;

    if ((hour >= 7 && hour <= 10) ||
        (hour >= 17 && hour <= 20)) {
      base = 0.8;
    } else if (hour >= 11 && hour <= 16) {
      base = 0.5;
    } else if (hour >= 21 || hour <= 5) {
      base = 0.25;
    } else {
      base = 0.45;
    }

    final lengthFactor =
        (distanceMeters / 60000.0)
            .clamp(0.0, 0.15);

    return (base + lengthFactor)
        .clamp(0.0, 1.0);
  }

  // ============================================================
  // REASONS
  // ============================================================

  List<String> _buildReasons({
    required SeatSide side,
    required RecommendationInput input,
    required SideScores left,
    required SideScores right,
    required double sunOnRightFraction,
    required bool isDaylightTrip,
    required List<Attraction> attractions,
    required double crowd,
  }) {
    final reasons = <String>[];

    // ------------------------------------------------------------
    // SUN
    // ------------------------------------------------------------

    if (isDaylightTrip) {
      final rightSunPercent =
          sunOnRightFraction * 100;

      final leftSunPercent =
          (1.0 - sunOnRightFraction) * 100;

      if ((rightSunPercent - leftSunPercent).abs() >= 10) {
        final sunnySide =
            rightSunPercent > leftSunPercent
                ? 'right'
                : 'left';

        final shadeSide =
            sunnySide == 'right'
                ? 'left'
                : 'right';

        final sunnyPct =
            math.max(
              rightSunPercent,
              leftSunPercent,
            );

        reasons.add(
          'The sun is on the $sunnySide for about '
          '${sunnyPct.round()}% of the trip, so the '
          '$shadeSide side gets more shade.',
        );
      } else {
        reasons.add(
          'Sun exposure is fairly balanced between both sides '
          'of the route.',
        );
      }
    } else {
      reasons.add(
        'Most of this trip happens after sunset, so sun and '
        'shade have little effect on comfort.',
      );
    }

    // ------------------------------------------------------------
    // SCORE COMPARISON
    // ------------------------------------------------------------

    final scoreGap =
        (left.total - right.total).abs();

    if (scoreGap < AppConstants.tieThreshold) {
      reasons.add(
        'Both sides score very similarly '
        '(${left.total.round()} vs ${right.total.round()}), '
        'so there is no strong seating advantage.',
      );
    } else {
      final betterSide =
          left.total > right.total
              ? 'left'
              : 'right';

      reasons.add(
        'The $betterSide side has the stronger overall score '
        '(${math.max(left.total, right.total).round()} vs '
        '${math.min(left.total, right.total).round()}).',
      );
    }

    // ------------------------------------------------------------
    // SCENIC
    // ------------------------------------------------------------

    final scenicDifference =
        (left.scenic - right.scenic).abs();

    if (scenicDifference >= 8) {
      final scenicSide =
          left.scenic > right.scenic
              ? 'left'
              : 'right';

      final picks = attractions
          .where(
            (a) =>
                (scenicSide == 'left' &&
                    a.side == SeatSide.left) ||
                (scenicSide == 'right' &&
                    a.side == SeatSide.right),
          )
          .take(3)
          .toList();

      if (picks.isNotEmpty) {
        reasons.add(
          'The $scenicSide side has better nearby views, '
          'including ${picks.map((a) => a.name).join(', ')}.',
        );
      } else {
        reasons.add(
          'The $scenicSide side has a stronger scenic score.',
        );
      }
    } else if (attractions.isEmpty) {
      reasons.add(
        'No standout landmarks were found close to this route.',
      );
    } else {
      reasons.add(
        'Scenic opportunities are fairly balanced between both sides.',
      );
    }

    // ------------------------------------------------------------
    // WEATHER
    // ------------------------------------------------------------

    if (input.weatherSamples.isNotEmpty) {
      final w = input.weatherSamples.first;

      if (w.isRaining) {
        reasons.add(
          'Rain is likely along the way (${w.description}); '
          'expect similar conditions on both sides.',
        );
      } else if (w.temperatureC >= 30) {
        reasons.add(
          'It is hot (~${Formatters.temperature(w.temperatureC)}), '
          'so shade has a stronger comfort benefit.',
        );
      } else if (w.temperatureC >= 26) {
        reasons.add(
          'Conditions are warm (~${Formatters.temperature(w.temperatureC)}), '
          'so shaded areas may feel more comfortable.',
        );
      } else {
        reasons.add(
          'Weather looks '
          '${w.description.isEmpty ? w.condition.toLowerCase() : w.description} '
          '(~${Formatters.temperature(w.temperatureC)}).',
        );
      }
    }

    // ------------------------------------------------------------
    // TRAVEL
    // ------------------------------------------------------------

    reasons.add(
      'Estimated travel time is '
      '${Formatters.duration(Duration(seconds: input.durationSeconds.round()))}, '
      'with a ${_crowdLabel(crowd).toLowerCase()} expected crowd.',
    );

    // ------------------------------------------------------------
    // TIE
    // ------------------------------------------------------------

    if (side == SeatSide.either) {
      reasons.add(
        'The two sides are very close overall, so choose '
        'whichever seat you prefer.',
      );
    }

    return reasons;
  }

  String _crowdLabel(double crowd) {
    if (crowd < 0.34) return 'Light';
    if (crowd < 0.67) return 'Moderate';
    return 'Busy';
  }

  String _headline(SeatSide side) {
    return switch (side) {
      SeatSide.left =>
        'Sit on the LEFT for the best ride',
      SeatSide.right =>
        'Sit on the RIGHT for the best ride',
      SeatSide.either =>
        'Either side works for this trip',
    };
  }

  SeatRecommendation _neutral(
    RecommendationInput input,
    String why,
  ) {
    const scores = SideScores(
      comfort: 50,
      scenic: 50,
      weather: 50,
      total: 50,
    );

    return SeatRecommendation(
      recommendedSide: SeatSide.either,
      confidence: 0.10,
      leftScores: scores,
      rightScores: scores,
      headline: 'Either side works for this trip',
      reasons: [why],
      etaSeconds: input.durationSeconds,
      crowdLevel: _estimateCrowd(
        input.departure,
        input.distanceMeters,
      ),
      attractions: const [],
      weatherSamples: input.weatherSamples,
      sunOnRightFraction: 0.5,
    );
  }
}