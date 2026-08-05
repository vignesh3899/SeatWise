import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/failure.dart';
import '../core/result.dart';
import '../models/journey.dart';
import '../repositories/recommendation_repository.dart';
import 'planner_controller.dart';
import 'providers.dart';

/// Runs a recommendation for the current planner selection and exposes the
/// result as an [AsyncValue]. Also persists the journey to the user's history.
class RecommendationController extends AsyncNotifier<RecommendationBundle?> {
  @override
  Future<RecommendationBundle?> build() async => null;

  Future<void> run() async {
    final planner = ref.read(plannerControllerProvider);
    if (!planner.isReady) {
      state = AsyncError(
        const ValidationFailure('Please choose both an origin and destination.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();

    final request = RecommendationRequest(
      origin: planner.origin!.coord,
      destination: planner.destination!.coord,
      departure: planner.departure,
      preferShade: planner.preferShade,
    );

    final result =
        await ref.read(recommendationRepositoryProvider).recommend(request);

    final bundle = result.valueOrNull;
    if (bundle != null) {
      state = AsyncData(bundle);
      await _persist(bundle, planner);
    } else {
      state = AsyncError(result.failureOrNull!, StackTrace.current);
    }
  }

  void clear() => state = const AsyncData(null);

  Future<Result<void>> _persist(
    RecommendationBundle bundle,
    PlannerState planner,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return const ResultFailure(AuthFailure('Not signed in.'));

    final journey = Journey(
      id: '',
      userId: user.uid,
      originLabel: planner.origin!.shortName,
      destinationLabel: planner.destination!.shortName,
      origin: planner.origin!.coord,
      destination: planner.destination!.coord,
      departureAt: planner.departure,
      createdAt: DateTime.now(),
      recommendedSide: bundle.recommendation.recommendedSide,
      headline: bundle.recommendation.headline,
      etaSeconds: bundle.recommendation.etaSeconds,
      recommendation: bundle.recommendation,
    );

    return ref.read(journeyRepositoryProvider).save(journey);
  }
}

final recommendationControllerProvider =
    AsyncNotifierProvider<RecommendationController, RecommendationBundle?>(
  RecommendationController.new,
);

/// Live list of the signed-in user's saved journeys (history).
final journeysProvider = StreamProvider.autoDispose<List<Journey>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(journeyRepositoryProvider).watchJourneys(user.uid);
});
