import '../core/constants.dart';
import '../models/place_suggestion.dart';
import 'api_client.dart';

/// Client for OpenStreetMap Nominatim geocoding (free, no key).
/// Usage policy: https://operations.osmfoundation.org/policies/nominatim/
///
/// A descriptive User-Agent is mandatory and is supplied by [ApiClient]. Callers
/// should debounce requests (max ~1 req/sec) which the search UI enforces.
class NominatimService {
  NominatimService(this._client);

  final ApiClient _client;

  /// Free-text search returning up to [limit] place suggestions.
  Future<List<PlaceSuggestion>> search(String query, {int limit = 6}) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final uri = Uri.parse('${AppConstants.nominatimBaseUrl}/search').replace(
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'addressdetails': '0',
        'limit': limit.toString(),
      },
    );

    final json = await _client.getJson(uri);
    final list = json as List<dynamic>;
    return list
        .map((e) =>
            PlaceSuggestion.fromNominatimJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
