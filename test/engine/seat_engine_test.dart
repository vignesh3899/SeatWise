import 'package:flutter_test/flutter_test.dart';
import 'package:seatwise/core/constants.dart';
import 'package:seatwise/engine/seat_engine.dart';
import 'package:seatwise/models/geo_coord.dart';
import 'package:seatwise/models/route_segment.dart';

/// Builds a simple straight eastbound route (heading 90°) around latitude 40N
/// on the Greenwich meridian, so at 12:00 UTC the sun is roughly due south and
/// therefore on the RIGHT of travel.
List<RouteSegment> _eastboundRoute() {
  return [
    const RouteSegment(
      start: GeoCoord(lat: 40, lng: 0.00),
      end: GeoCoord(lat: 40, lng: 0.05),
      headingDegrees: 90,
      lengthMeters: 4000,
      cumulativeSeconds: 0,
    ),
    const RouteSegment(
      start: GeoCoord(lat: 40, lng: 0.05),
      end: GeoCoord(lat: 40, lng: 0.10),
      headingDegrees: 90,
      lengthMeters: 4000,
      cumulativeSeconds: 120,
    ),
  ];
}

void main() {
  const engine = SeatEngine();

  test('empty route yields a neutral either-side result', () {
    final rec = engine.recommend(
      RecommendationInput(
        segments: const [],
        departure: DateTime.utc(2024, 6, 21, 12),
        weatherSamples: const [],
        attractions: const [],
        distanceMeters: 0,
        durationSeconds: 0,
      ),
    );
    expect(rec.recommendedSide, SeatSide.either);
    expect(rec.confidence, 0);
  });

  test('midday eastbound: sun on the right, recommends the shaded LEFT', () {
    final rec = engine.recommend(
      RecommendationInput(
        segments: _eastboundRoute(),
        departure: DateTime.utc(2024, 6, 21, 12),
        weatherSamples: const [],
        attractions: const [],
        distanceMeters: 8000,
        durationSeconds: 240,
        preferShade: true,
      ),
    );
    expect(rec.recommendedSide, SeatSide.left);
    expect(rec.sunOnRightFraction, greaterThan(0.5));
    expect(rec.leftScores.comfort, greaterThan(rec.rightScores.comfort));
    expect(rec.confidence, greaterThan(0));
    expect(rec.reasons, isNotEmpty);
  });

  test('preferring sun flips the same trip to the RIGHT', () {
    final rec = engine.recommend(
      RecommendationInput(
        segments: _eastboundRoute(),
        departure: DateTime.utc(2024, 6, 21, 12),
        weatherSamples: const [],
        attractions: const [],
        distanceMeters: 8000,
        durationSeconds: 240,
        preferShade: false,
      ),
    );
    expect(rec.recommendedSide, SeatSide.right);
  });

  test('night trip returns either side and explains sun does not matter', () {
    final rec = engine.recommend(
      RecommendationInput(
        segments: _eastboundRoute(),
        departure: DateTime.utc(2024, 6, 21, 0),
        weatherSamples: const [],
        attractions: const [],
        distanceMeters: 8000,
        durationSeconds: 240,
      ),
    );
    expect(rec.recommendedSide, SeatSide.either);
    expect(
      rec.reasons.any((r) => r.toLowerCase().contains('sunset')),
      isTrue,
    );
  });

  test('recommendation is deterministic for identical input', () {
    final input = RecommendationInput(
      segments: _eastboundRoute(),
      departure: DateTime.utc(2024, 6, 21, 12),
      weatherSamples: const [],
      attractions: const [],
      distanceMeters: 8000,
      durationSeconds: 240,
    );
    final a = engine.recommend(input);
    final b = engine.recommend(input);
    expect(a.recommendedSide, b.recommendedSide);
    expect(a.leftScores.total, b.leftScores.total);
    expect(a.rightScores.total, b.rightScores.total);
  });
}
