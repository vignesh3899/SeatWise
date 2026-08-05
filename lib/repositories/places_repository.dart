import '../core/exceptions.dart';
import '../core/failure.dart';
import '../core/result.dart';
import '../models/place_suggestion.dart';
import '../services/connectivity_service.dart';
import '../services/nominatim_service.dart';

/// Geocoding / place-search repository backed by Nominatim.
class PlacesRepository {
  PlacesRepository({
    required NominatimService nominatim,
    required ConnectivityService connectivity,
  })  : _nominatim = nominatim,
        _connectivity = connectivity;

  final NominatimService _nominatim;
  final ConnectivityService _connectivity;

  Future<Result<List<PlaceSuggestion>>> search(String query) async {
    if (!await _connectivity.isOnline) {
      return const ResultFailure(NetworkFailure());
    }
    try {
      final results = await _nominatim.search(query);
      return Success(results);
    } on ApiException catch (e) {
      return ResultFailure(ApiFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return ResultFailure(UnexpectedFailure('Place search failed: $e'));
    }
  }
}
