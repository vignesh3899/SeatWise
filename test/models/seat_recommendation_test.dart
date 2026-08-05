import 'package:flutter_test/flutter_test.dart';
import 'package:seatwise/core/constants.dart';
import 'package:seatwise/models/attraction.dart';
import 'package:seatwise/models/geo_coord.dart';
import 'package:seatwise/models/seat_recommendation.dart';
import 'package:seatwise/models/weather_point.dart';

void main() {
  test('SeatRecommendation survives a JSON round-trip', () {
    const original = SeatRecommendation(
      recommendedSide: SeatSide.left,
      confidence: 0.42,
      leftScores: SideScores(comfort: 80, scenic: 60, weather: 55, total: 68),
      rightScores: SideScores(comfort: 20, scenic: 40, weather: 45, total: 32),
      headline: 'Sit on the LEFT for the best ride',
      reasons: ['Shade on the left', 'Great views on the left'],
      etaSeconds: 3600,
      crowdLevel: 0.5,
      attractions: [
        Attraction(
          name: 'Old Fort',
          location: GeoCoord(lat: 12.9, lng: 77.6),
          category: 'castle',
          rating: 4.2,
          side: SeatSide.left,
          distanceFromRouteMeters: 220,
        ),
      ],
      weatherSamples: [
        WeatherPoint(
          temperatureC: 29,
          cloudPercent: 20,
          condition: 'Clear',
          description: 'clear sky',
          icon: '01d',
        ),
      ],
      sunOnRightFraction: 0.8,
    );

    final restored =
        SeatRecommendation.fromJson(original.toJson());

    expect(restored.recommendedSide, original.recommendedSide);
    expect(restored.confidence, original.confidence);
    expect(restored.headline, original.headline);
    expect(restored.reasons, original.reasons);
    expect(restored.leftScores, original.leftScores);
    expect(restored.rightScores, original.rightScores);
    expect(restored.attractions.first.name, 'Old Fort');
    expect(restored.attractions.first.side, SeatSide.left);
    expect(restored.weatherSamples.first.temperatureC, 29);
    expect(restored.sunOnRightFraction, 0.8);
  });

  test('crowd label thresholds', () {
    SeatRecommendation withCrowd(double c) => SeatRecommendation(
          recommendedSide: SeatSide.either,
          confidence: 0,
          leftScores: const SideScores(comfort: 50, scenic: 50, weather: 50, total: 50),
          rightScores: const SideScores(comfort: 50, scenic: 50, weather: 50, total: 50),
          headline: '',
          reasons: const [],
          etaSeconds: 0,
          crowdLevel: c,
          attractions: const [],
          weatherSamples: const [],
          sunOnRightFraction: 0.5,
        );
    expect(withCrowd(0.1).crowdLabel, 'Light');
    expect(withCrowd(0.5).crowdLabel, 'Moderate');
    expect(withCrowd(0.9).crowdLabel, 'Busy');
  });
}
