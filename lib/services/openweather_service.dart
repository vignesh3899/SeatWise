import '../config/env.dart';
import '../core/constants.dart';
import '../core/exceptions.dart';
import '../models/geo_coord.dart';
import '../models/weather_point.dart';
import 'api_client.dart';

/// Client for the free OpenWeather "current weather" API.
/// Docs: https://openweathermap.org/current
///
/// The free tier does not expose per-minute forecasts along an arbitrary path,
/// so we sample current conditions at a handful of points along the route. This
/// is a good proxy for a short/medium bus journey.
class OpenWeatherService {
  OpenWeatherService(this._client);

  final ApiClient _client;

  Future<WeatherPoint> getWeatherAt(GeoCoord coord) async {
    if (!Env.hasWeatherKey) {
      throw ApiException('OpenWeather API key is not configured.');
    }

    final uri = Uri.parse('${AppConstants.openWeatherBaseUrl}/weather').replace(
      queryParameters: {
        'lat': coord.lat.toString(),
        'lon': coord.lng.toString(),
        'units': 'metric',
        'appid': Env.openWeatherApiKey,
      },
    );

    final json = await _client.getJson(uri);
    return WeatherPoint.fromOpenWeatherJson(json as Map<String, dynamic>);
  }

  /// Fetches weather for several sample points concurrently.
  Future<List<WeatherPoint>> getWeatherForPoints(List<GeoCoord> points) async {
    final futures = points.map(getWeatherAt);
    return Future.wait(futures);
  }
}
