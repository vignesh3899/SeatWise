import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:seatwise/core/constants.dart';
import 'package:seatwise/core/result.dart';
import 'package:seatwise/models/geo_coord.dart';
import 'package:seatwise/models/place_suggestion.dart';
import 'package:seatwise/models/route_data.dart';
import 'package:seatwise/models/seat_recommendation.dart';
import 'package:seatwise/providers/planner_controller.dart';
import 'package:seatwise/providers/providers.dart';
import 'package:seatwise/repositories/recommendation_repository.dart';
import 'package:seatwise/screens/planner/journey_planner_screen.dart';

/// A stub repository that returns a canned recommendation so the primary
/// planner -> recommendation flow can be exercised without network or Firebase.
class _FakeRecommendationRepository implements RecommendationRepository {
  @override
  Future<Result<RecommendationBundle>> recommend(
    RecommendationRequest request,
  ) async {
    const recommendation = SeatRecommendation(
      recommendedSide: SeatSide.left,
      confidence: 0.7,
      leftScores: SideScores(comfort: 80, scenic: 65, weather: 55, total: 70),
      rightScores: SideScores(comfort: 20, scenic: 35, weather: 45, total: 30),
      headline: 'Sit on the LEFT for the best ride',
      reasons: ['The sun is on the right for most of the trip.'],
      etaSeconds: 3600,
      crowdLevel: 0.4,
      attractions: [],
      weatherSamples: [],
      sunOnRightFraction: 0.85,
    );
    final route = RouteData(
      polyline: [request.origin, request.destination],
      distanceMeters: 12000,
      durationSeconds: 3600,
    );
    return const Success(
      RecommendationBundle(route: _route, recommendation: recommendation),
    );
  }

  // A const route cannot capture request coords, so we expose a helper instead.
  static const RouteData _route = RouteData(
    polyline: [GeoCoord(lat: 40, lng: 0), GeoCoord(lat: 40, lng: 0.1)],
    distanceMeters: 12000,
    durationSeconds: 3600,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Avoid dotenv "not initialised" errors when Env is read by the UI.
    dotenv.testLoad(fileInput: '');
  });

  testWidgets('planner produces a recommendation and shows the headline',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        recommendationRepositoryProvider
            .overrideWithValue(_FakeRecommendationRepository()),
      ],
    );
    addTearDown(container.dispose);

    // Pre-fill the planner as if the user had picked two places.
    container.read(plannerControllerProvider.notifier).setOrigin(
          const PlaceSuggestion(
            displayName: 'City Center',
            coord: GeoCoord(lat: 40, lng: 0),
          ),
        );
    container.read(plannerControllerProvider.notifier).setDestination(
          const PlaceSuggestion(
            displayName: 'Beach Town',
            coord: GeoCoord(lat: 40, lng: 0.1),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: JourneyPlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('Get seat recommendation');
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Sit on the LEFT for the best ride'), findsOneWidget);
    expect(find.textContaining('Why this side'), findsOneWidget);
  });
}
