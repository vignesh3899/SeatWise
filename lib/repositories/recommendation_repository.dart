import 'package:cloud_functions/cloud_functions.dart' as cf;

import '../config/env.dart';
import '../core/constants.dart';
import '../core/exceptions.dart';
import '../core/failure.dart';
import '../core/result.dart';
import '../engine/route_sampler.dart';
import '../engine/seat_engine.dart';
import '../models/attraction.dart';
import '../models/geo_coord.dart';
import '../models/route_data.dart';
import '../models/seat_recommendation.dart';
import '../models/weather_point.dart';
import '../services/connectivity_service.dart';
import '../services/openroute_service.dart';
import '../services/openweather_service.dart';
import '../services/overpass_service.dart';
import '../utils/logger.dart';

/// The route plus the recommendation computed for it. The map and timeline
/// screens need the polyline, which is not part of [SeatRecommendation].
class RecommendationBundle {
  const RecommendationBundle({required this.route, required this.recommendation});

  final RouteData route;
  final SeatRecommendation recommendation;
}

/// Parameters for a recommendation request.
class RecommendationRequest {
  const RecommendationRequest({
    required this.origin,
    required this.destination,
    required this.departure,
    this.preferShade = true,
  });

  final GeoCoord origin;
  final GeoCoord destination;
  final DateTime departure;
  final bool preferShade;
}

/// Orchestrates the full recommendation pipeline. When [Env.useCloudEngine] is
/// on and the network is reachable it defers to the Cloud Function; otherwise it
/// runs the identical on-device [SeatEngine]. Sub-requests (weather, attractions)
/// fail soft so a partial data source never blocks a recommendation.
class RecommendationRepository {
  RecommendationRepository({
    required OpenRouteService routeService,
    required OpenWeatherService weatherService,
    required OverpassService overpassService,
    required ConnectivityService connectivity,
    RouteSampler sampler = const RouteSampler(),
    SeatEngine engine = const SeatEngine(),
    cf.FirebaseFunctions? functions,
  })  : _routeService = routeService,
        _weatherService = weatherService,
        _overpassService = overpassService,
        _connectivity = connectivity,
        _sampler = sampler,
        _engine = engine,
        _functions = functions;

  final OpenRouteService _routeService;
  final OpenWeatherService _weatherService;
  final OverpassService _overpassService;
  final ConnectivityService _connectivity;
  final RouteSampler _sampler;
  final SeatEngine _engine;
  final cf.FirebaseFunctions? _functions;

  Future<Result<RecommendationBundle>> recommend(
    RecommendationRequest request,
  ) async {
    if (!await _connectivity.isOnline) {
      return const ResultFailure(NetworkFailure());
    }

    // 1. Route is required for everything else.
    final RouteData route;
    try {
      route = await _routeService.getRoute(
        origin: request.origin,
        destination: request.destination,
      );
    } on ApiException catch (e) {
      return ResultFailure(ApiFailure(
        e.statusCode == 401
            ? 'OpenRouteService rejected the API key. Check your .env.'
            : 'Could not fetch a route: ${e.message}',
        statusCode: e.statusCode,
      ));
    } catch (e) {
      return ResultFailure(UnexpectedFailure('Routing failed: $e'));
    }

    if (Env.useCloudEngine) {
      final cloud = await _tryCloud(request);
      if (cloud != null) {
        return Success(RecommendationBundle(route: route, recommendation: cloud));
      }
      Log.d('Cloud engine unavailable; falling back to on-device engine.');
    }

    // 2. Gather context (fail soft).
    final segments = _sampler.sample(route);
    final weather = await _fetchWeather(route);
    final attractions = await _fetchAttractions(route);

    // 3. Run the deterministic engine.
    final recommendation = _engine.recommend(
      RecommendationInput(
        segments: segments,
        departure: request.departure,
        weatherSamples: weather,
        attractions: attractions,
        distanceMeters: route.distanceMeters,
        durationSeconds: route.durationSeconds,
        preferShade: request.preferShade,
      ),
    );

    return Success(
      RecommendationBundle(route: route, recommendation: recommendation),
    );
  }

  Future<List<WeatherPoint>> _fetchWeather(RouteData route) async {
    try {
      final points = _samplePoints(route.polyline, 4);
      return await _weatherService.getWeatherForPoints(points);
    } catch (e) {
      Log.d('Weather lookup failed (continuing without it): $e');
      return const [];
    }
  }

  Future<List<Attraction>> _fetchAttractions(RouteData route) async {
    try {
      final bbox = _sampler.boundingBox(route.polyline);
      return await _overpassService.findAttractions(
        south: bbox.south,
        west: bbox.west,
        north: bbox.north,
        east: bbox.east,
      );
    } catch (e) {
      Log.d('Attraction lookup failed (continuing without it): $e');
      return const [];
    }
  }

  /// Evenly spaced sample coordinates along a polyline (including both ends).
  List<GeoCoord> _samplePoints(List<GeoCoord> polyline, int count) {
    if (polyline.length <= count) return polyline;
    final result = <GeoCoord>[];
    for (var i = 0; i < count; i++) {
      final idx = ((polyline.length - 1) * i / (count - 1)).round();
      result.add(polyline[idx]);
    }
    return result;
  }

  Future<SeatRecommendation?> _tryCloud(RecommendationRequest request) async {
    try {
      final functions = _functions ?? cf.FirebaseFunctions.instance;
      final callable = functions.httpsCallable(AppConstants.recommendFunction);
      final response = await callable.call<Map<String, dynamic>>({
        'origin': request.origin.toJson(),
        'destination': request.destination.toJson(),
        'departureIso': request.departure.toUtc().toIso8601String(),
        'preferShade': request.preferShade,
      });
      return SeatRecommendation.fromJson(
        Map<String, dynamic>.from(response.data),
      );
    } catch (e) {
      Log.d('Cloud function call failed: $e');
      return null;
    }
  }
}
