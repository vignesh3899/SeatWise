import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place_suggestion.dart';
import 'providers.dart';

/// Immutable state of the journey-planner form.
@immutable
class PlannerState {
  const PlannerState({
    this.origin,
    this.destination,
    required this.departure,
    this.preferShade = true,
  });

  final PlaceSuggestion? origin;
  final PlaceSuggestion? destination;
  final DateTime departure;
  final bool preferShade;

  bool get isReady => origin != null && destination != null;

  PlannerState copyWith({
    PlaceSuggestion? origin,
    PlaceSuggestion? destination,
    DateTime? departure,
    bool? preferShade,
    bool clearOrigin = false,
    bool clearDestination = false,
  }) {
    return PlannerState(
      origin: clearOrigin ? null : (origin ?? this.origin),
      destination: clearDestination ? null : (destination ?? this.destination),
      departure: departure ?? this.departure,
      preferShade: preferShade ?? this.preferShade,
    );
  }
}

/// Holds the user's origin/destination/time selection for the planner screen.
class PlannerController extends Notifier<PlannerState> {
  @override
  PlannerState build() {
    final user = ref.watch(currentUserProvider);
    return PlannerState(
      departure: DateTime.now(),
      preferShade: user?.preferShade ?? true,
    );
  }

  void setOrigin(PlaceSuggestion place) =>
      state = state.copyWith(origin: place);

  void setDestination(PlaceSuggestion place) =>
      state = state.copyWith(destination: place);

  void setDeparture(DateTime when) => state = state.copyWith(departure: when);

  void setPreferShade(bool value) =>
      state = state.copyWith(preferShade: value);

  void swap() {
    state = PlannerState(
      origin: state.destination,
      destination: state.origin,
      departure: state.departure,
      preferShade: state.preferShade,
    );
  }

  void reset() => state = PlannerState(
        departure: DateTime.now(),
        preferShade: state.preferShade,
      );
}

final plannerControllerProvider =
    NotifierProvider<PlannerController, PlannerState>(PlannerController.new);

/// Debounced place search for the planner's origin/destination fields.
final placeSearchProvider =
    FutureProvider.autoDispose.family<List<PlaceSuggestion>, String>(
  (ref, query) async {
    if (query.trim().length < 3) return const [];
    // Small debounce so we respect Nominatim's ~1 req/sec policy. If the query
    // changes, this autoDispose provider is torn down and the delay is dropped.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final result = await ref.watch(placesRepositoryProvider).search(query);
    return result.valueOrNull ?? const [];
  },
);
