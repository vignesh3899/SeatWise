import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/feedback_repository.dart';
import '../repositories/journey_repository.dart';
import '../repositories/places_repository.dart';
import '../repositories/recommendation_repository.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/nominatim_service.dart';
import '../services/openroute_service.dart';
import '../services/openweather_service.dart';
import '../services/overpass_service.dart';

/// Central dependency-injection graph for SeatWise. Every service and repository
/// is exposed as a Riverpod provider so screens/controllers depend on
/// abstractions that are trivially overridable in tests.

/// Overridden in `main()` after `SharedPreferences.getInstance()` completes.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences not initialised'),
);

// --- Low level ---------------------------------------------------------------

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

// --- Services ----------------------------------------------------------------

final openRouteServiceProvider = Provider<OpenRouteService>(
  (ref) => OpenRouteService(ref.watch(apiClientProvider)),
);

final openWeatherServiceProvider = Provider<OpenWeatherService>(
  (ref) => OpenWeatherService(ref.watch(apiClientProvider)),
);

final nominatimServiceProvider = Provider<NominatimService>(
  (ref) => NominatimService(ref.watch(apiClientProvider)),
);

final overpassServiceProvider = Provider<OverpassService>(
  (ref) => OverpassService(ref.watch(apiClientProvider)),
);

// --- Repositories ------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final journeyRepositoryProvider =
    Provider<JourneyRepository>((ref) => JourneyRepository());

final feedbackRepositoryProvider =
    Provider<FeedbackRepository>((ref) => FeedbackRepository());

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(
    nominatim: ref.watch(nominatimServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  ),
);

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepository(
    routeService: ref.watch(openRouteServiceProvider),
    weatherService: ref.watch(openWeatherServiceProvider),
    overpassService: ref.watch(overpassServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  ),
);

// --- Auth state --------------------------------------------------------------

/// Streams the currently signed-in [AppUser] (or null). The whole app routes on
/// this single source of truth.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authState(),
);

/// Convenience accessor for the current user id inside controllers.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);
