import 'dart:math' as math;

import '../core/constants.dart';
import '../core/geo.dart';
import '../models/attraction.dart';
import '../models/route_segment.dart';
import '../models/seat_recommendation.dart';
import '../models/weather_point.dart';
import '../utils/formatters.dart';
import 'sun_calculator.dart';

/// Everything the [SeatEngine] needs to produce a recommendation. Assembled by
/// the recommendation repository from the route, weather and attraction data.
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

  /// Weather samples in route order (may be fewer than segments; the engine
  /// maps each segment to the nearest available sample by index fraction).
  final List<WeatherPoint> weatherSamples;

  final List<Attraction> attractions;
  final double distanceMeters;
  final double durationSeconds;
  final bool preferShade;
}

/// The core, fully deterministic recommendation engine. Given a route and its
/// context it computes per-side comfort, scenic and weather scores and returns
/// a [SeatRecommendation] with an explanation. Pure and unit-tested — it makes
/// no network calls, so it doubles as the offline fallback.
class SeatEngine {
  const SeatEngine();

  SeatRecommendation recommend(RecommendationInput input) {
    final segments = input.segments;
    if (segments.isEmpty) {
      return _neutral(input, 'We could not read the route geometry.');
    }

    // ---- 1. Sun / shade load per side ---------------------------------------
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
      final sun = SunCalculator.position(time.toUtc(), seg.midpoint);
      if (!sun.isDaylight) continue;

      final weather = _weatherForSegment(input, seg, segments);
      final clearness = weather?.clearness ?? 0.8;

      final altRad = sun.altitudeDegrees * math.pi / 180.0;
      final illumination = math.max(0.0, math.sin(altRad)); // overall sunshine
      final laterality = math.cos(altRad).abs(); // side-specificity (low sun)
      final rel = Geo.normalizeSignedDegrees(
        sun.azimuthDegrees - seg.headingDegrees,
      );
      final perpendicular = math.sin(rel * math.pi / 180.0).abs();

      final load = weight *
          illumination *
          (0.35 + 0.65 * laterality) *
          perpendicular *
          clearness;

      daylightWeight += weight * illumination;

      final side = Geo.sideOfHeading(seg.headingDegrees, sun.azimuthDegrees);
      if (side > 0) {
        rightSunLoad += load;
        sunOnRightWeight += weight;
      } else if (side < 0) {
        leftSunLoad += load;
      }
    }

    final sunOnRightFraction =
        totalWeight > 0 ? (sunOnRightWeight / totalWeight) : 0.5;
    final totalLoad = leftSunLoad + rightSunLoad;
    final isDaylightTrip = daylightWeight > totalWeight * 0.05;

    // Comfort: the shadier side scores higher (unless the user prefers sun).
    double comfortLeft;
    double comfortRight;
    if (totalLoad < 1e-6) {
      comfortLeft = comfortRight = 50.0;
    } else {
      // Share of sun each side receives; more sun => less shade comfort.
      final rightShare = rightSunLoad / totalLoad; // 0..1
      final leftShare = leftSunLoad / totalLoad;
      if (input.preferShade) {
        comfortLeft = 100.0 * rightShare; // left is comfy when sun is on right
        comfortRight = 100.0 * leftShare;
      } else {
        comfortLeft = 100.0 * leftShare;
        comfortRight = 100.0 * rightShare;
      }
    }

    // ---- 2. Scenic score per side -------------------------------------------
    final sidedAttractions = _assignSides(input.attractions, segments);
    var scenicLeftRaw = 0.0;
    var scenicRightRaw = 0.0;
    for (final a in sidedAttractions) {
      final proximity = (1.0 -
              (a.distanceFromRouteMeters /
                  AppConstants.attractionSearchRadiusMeters))
          .clamp(0.0, 1.0);
      final value = (a.rating ?? 2.5) * (0.4 + 0.6 * proximity);
      if (a.side == SeatSide.left) {
        scenicLeftRaw += value;
      } else if (a.side == SeatSide.right) {
        scenicRightRaw += value;
      }
    }
    final scenicTotal = scenicLeftRaw + scenicRightRaw;
    final scenicLeft =
        scenicTotal < 1e-6 ? 50.0 : 100.0 * scenicLeftRaw / scenicTotal;
    final scenicRight =
        scenicTotal < 1e-6 ? 50.0 : 100.0 * scenicRightRaw / scenicTotal;

    // ---- 3. Weather-driven comfort ------------------------------------------
    final weatherPair = _weatherScores(
      input,
      leftIsShade: leftSunLoad <= rightSunLoad,
      isDaylightTrip: isDaylightTrip,
    );

    // ---- 4. Blend into final per-side totals --------------------------------
    final left = SideScores(
      comfort: comfortLeft,
      scenic: scenicLeft,
      weather: weatherPair.left,
      total: _blend(comfortLeft, scenicLeft, weatherPair.left),
    );
    final right = SideScores(
      comfort: comfortRight,
      scenic: scenicRight,
      weather: weatherPair.right,
      total: _blend(comfortRight, scenicRight, weatherPair.right),
    );

    final gap = (left.total - right.total).abs();
    final SeatSide side;
    if (gap < AppConstants.tieThreshold) {
      side = SeatSide.either;
    } else {
      side = left.total > right.total ? SeatSide.left : SeatSide.right;
    }
    final confidence = (gap / 25.0).clamp(0.0, 1.0);

    final crowd = _estimateCrowd(input.departure, input.distanceMeters);

    final reasons = _buildReasons(
      side: side,
      input: input,
      left: left,
      right: right,
      sunOnRightFraction: sunOnRightFraction,
      isDaylightTrip: isDaylightTrip,
      attractions: sidedAttractions,
      crowd: crowd,
    );

    return SeatRecommendation(
      recommendedSide: side,
      confidence: confidence,
      leftScores: left,
      rightScores: right,
      headline: _headline(side),
      reasons: reasons,
      etaSeconds: input.durationSeconds,
      crowdLevel: crowd,
      attractions: sidedAttractions,
      weatherSamples: input.weatherSamples,
      sunOnRightFraction: sunOnRightFraction,
    );
  }

  // --- helpers ---------------------------------------------------------------

  double _blend(double comfort, double scenic, double weather) =>
      (AppConstants.weightComfort * comfort +
              AppConstants.weightScenic * scenic +
              AppConstants.weightWeather * weather)
          .clamp(0.0, 100.0);

  WeatherPoint? _weatherForSegment(
    RecommendationInput input,
    RouteSegment seg,
    List<RouteSegment> segments,
  ) {
    if (input.weatherSamples.isEmpty) return null;
    final index = segments.indexOf(seg);
    final fraction = segments.length > 1 ? index / (segments.length - 1) : 0.0;
    final sampleIndex =
        (fraction * (input.weatherSamples.length - 1)).round().clamp(
              0,
              input.weatherSamples.length - 1,
            );
    return input.weatherSamples[sampleIndex];
  }

  List<Attraction> _assignSides(
    List<Attraction> attractions,
    List<RouteSegment> segments,
  ) {
    final result = <Attraction>[];
    for (final a in attractions) {
      RouteSegment? nearest;
      var nearestDist = double.infinity;
      for (final seg in segments) {
        final d = Geo.crossTrackDistanceMeters(seg.start, seg.end, a.location);
        if (d < nearestDist) {
          nearestDist = d;
          nearest = seg;
        }
      }
      if (nearest == null) continue;
      final bearingToA = Geo.bearingDegrees(nearest.midpoint, a.location);
      final sideSign = Geo.sideOfHeading(nearest.headingDegrees, bearingToA);
      final side = sideSign > 0
          ? SeatSide.right
          : sideSign < 0
              ? SeatSide.left
              : SeatSide.either;
      result.add(
        a.copyWith(side: side, distanceFromRouteMeters: nearestDist),
      );
    }
    // Keep only reasonably close attractions, best first, capped per side.
    result.sort((x, y) =>
        (y.rating ?? 0).compareTo(x.rating ?? 0));
    return result
        .where((a) =>
            a.distanceFromRouteMeters <=
            AppConstants.attractionSearchRadiusMeters)
        .toList();
  }

  ({double left, double right}) _weatherScores(
    RecommendationInput input, {
    required bool leftIsShade,
    required bool isDaylightTrip,
  }) {
    if (input.weatherSamples.isEmpty || !isDaylightTrip) {
      return (left: 50.0, right: 50.0);
    }
    final avgTemp = input.weatherSamples
            .map((w) => w.temperatureC)
            .reduce((a, b) => a + b) /
        input.weatherSamples.length;
    final avgClearness = input.weatherSamples
            .map((w) => w.clearness)
            .reduce((a, b) => a + b) /
        input.weatherSamples.length;

    final heatFactor = ((avgTemp - 22.0) / 13.0).clamp(0.0, 1.0);
    final advantage = heatFactor * avgClearness * 25.0; // up to 25 points

    // The shadier side gets the advantage when it is warm and sunny.
    final shadeGetsBonus = input.preferShade;
    final signedAdvantage = shadeGetsBonus ? advantage : -advantage;

    final shadeLeft = leftIsShade ? 50.0 + signedAdvantage : 50.0 - signedAdvantage;
    return (left: shadeLeft.clamp(0.0, 100.0), right: (100.0 - shadeLeft).clamp(0.0, 100.0));
  }

  /// Estimates crowding from departure time-of-day and trip length. Peak commute
  /// hours and longer intercity trips skew busier. Returns 0..1.
  double _estimateCrowd(DateTime departure, double distanceMeters) {
    final hour = departure.hour;
    double base;
    if ((hour >= 7 && hour <= 10) || (hour >= 17 && hour <= 20)) {
      base = 0.8; // rush hour
    } else if (hour >= 11 && hour <= 16) {
      base = 0.5; // midday
    } else if (hour >= 21 || hour <= 5) {
      base = 0.25; // late night / early morning
    } else {
      base = 0.45;
    }
    // Longer trips tend to fill up a little more.
    final lengthFactor = (distanceMeters / 60000.0).clamp(0.0, 0.15);
    return (base + lengthFactor).clamp(0.0, 1.0);
  }

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
    final sunnySide = sunOnRightFraction >= 0.5 ? 'right' : 'left';
    final shadeSide = sunnySide == 'right' ? 'left' : 'right';
    final sunnyPct = (sunOnRightFraction >= 0.5
            ? sunOnRightFraction
            : 1 - sunOnRightFraction) *
        100;

    if (isDaylightTrip) {
      reasons.add(
        'The sun is on the $sunnySide for about ${sunnyPct.round()}% of the '
        'trip, so the $shadeSide side stays shadier and cooler.',
      );
    } else {
      reasons.add(
        'Most of this trip happens after sunset, so sun and shade barely '
        'affect your comfort.',
      );
    }

    final leftPicks = attractions.where((a) => a.side == SeatSide.left).take(3);
    final rightPicks =
        attractions.where((a) => a.side == SeatSide.right).take(3);
    final scenicSide = right.scenic > left.scenic ? 'right' : 'left';
    final picks = scenicSide == 'right' ? rightPicks : leftPicks;
    if (picks.isNotEmpty) {
      reasons.add(
        'Scenic highlights on the $scenicSide include '
        '${picks.map((a) => a.name).join(', ')}.',
      );
    } else if (attractions.isEmpty) {
      reasons.add('No standout landmarks were found close to this route.');
    }

    if (input.weatherSamples.isNotEmpty) {
      final w = input.weatherSamples.first;
      if (w.isRaining) {
        reasons.add(
          'Rain is likely along the way (${w.description}); expect some '
          'window streaking on both sides.',
        );
      } else if (w.temperatureC >= 30) {
        reasons.add(
          'It is hot (~${Formatters.temperature(w.temperatureC)}), which makes '
          'the shaded side noticeably more comfortable.',
        );
      } else {
        reasons.add(
          'Weather looks ${w.description.isEmpty ? w.condition.toLowerCase() : w.description} '
          '(~${Formatters.temperature(w.temperatureC)}).',
        );
      }
    }

    reasons.add(
      'Estimated travel time is '
      '${Formatters.duration(Duration(seconds: input.durationSeconds.round()))}, '
      'with a ${_crowdLabel(crowd).toLowerCase()} expected crowd.',
    );

    if (side == SeatSide.either) {
      reasons.add(
        'The two sides are very close, so pick whichever seat you like.',
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
      SeatSide.left => 'Sit on the LEFT for the best ride',
      SeatSide.right => 'Sit on the RIGHT for the best ride',
      SeatSide.either => 'Either side works for this trip',
    };
  }

  SeatRecommendation _neutral(RecommendationInput input, String why) {
    const scores = SideScores(comfort: 50, scenic: 50, weather: 50, total: 50);
    return SeatRecommendation(
      recommendedSide: SeatSide.either,
      confidence: 0,
      leftScores: scores,
      rightScores: scores,
      headline: 'Either side works for this trip',
      reasons: [why],
      etaSeconds: input.durationSeconds,
      crowdLevel: _estimateCrowd(input.departure, input.distanceMeters),
      attractions: const [],
      weatherSamples: input.weatherSamples,
      sunOnRightFraction: 0.5,
    );
  }
}
