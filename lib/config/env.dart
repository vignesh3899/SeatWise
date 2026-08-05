import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables loaded from the bundled `.env` asset.
///
/// Keys are never hardcoded in source. If a key is missing the getters return
/// an empty string and [isConfigured] reports what is available so the UI can
/// warn the user instead of failing with an opaque 401.
class Env {
  Env._();

  static String _get(String key) => dotenv.maybeGet(key)?.trim() ?? '';

  static String get openRouteApiKey => _get('OPEN_ROUTE_API_KEY');
  static String get openWeatherApiKey => _get('OPEN_WEATHER_API_KEY');
  static String get firebaseProjectId => _get('FIREBASE_PROJECT_ID');
  static String get firebaseApiKey => _get('FIREBASE_API_KEY');

  /// When true the app prefers the deployed Cloud Function for recommendations.
  static bool get useCloudEngine =>
      _get('USE_CLOUD_ENGINE').toLowerCase() == 'true';

  static bool get hasRoutingKey => openRouteApiKey.isNotEmpty;
  static bool get hasWeatherKey => openWeatherApiKey.isNotEmpty;

  /// Loads the `.env` file. Safe to call once during startup; if the file is
  /// absent (e.g. first checkout) it loads empty so the app still boots.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      dotenv.testLoad(fileInput: '');
    }
  }
}
