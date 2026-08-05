import '../core/constants.dart';
import '../models/attraction.dart';
import '../models/geo_coord.dart';
import 'api_client.dart';

/// Client for the OpenStreetMap Overpass API (free, no key).
///
/// Finds tourism / natural / historic points of interest inside a bounding box
/// that encloses the route. The engine later assigns each attraction to the
/// left or right side of travel.
class OverpassService {
  OverpassService(this._client);

  final ApiClient _client;

  /// OSM tags we treat as "scenic" or worth looking at from a bus window.
  static const List<String> _scenicKeys = [
    'tourism~"^(viewpoint|attraction|artwork|museum|gallery|zoo|theme_park)\$"',
    'natural~"^(peak|beach|water|waterfall|bay|cliff|volcano)\$"',
    'historic~"^(castle|monument|ruins|memorial|fort|archaeological_site)\$"',
    'leisure~"^(park|nature_reserve|garden)\$"',
    'waterway~"^(waterfall)\$"',
  ];

  /// Returns attractions within [bbox] (south, west, north, east).
  Future<List<Attraction>> findAttractions({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final bbox = '$south,$west,$north,$east';
    final clauses = _scenicKeys
        .map((k) => 'node[$k]($bbox);way[$k]($bbox);')
        .join('\n');

    final query = '''
[out:json][timeout:25];
(
$clauses
);
out center 200;
''';

    final json = await _client.postForm(
      Uri.parse(AppConstants.overpassBaseUrl),
      {'data': query},
    );

    final elements = (json as Map<String, dynamic>)['elements'] as List<dynamic>?;
    if (elements == null) return const [];

    final result = <Attraction>[];
    for (final el in elements) {
      final e = el as Map<String, dynamic>;
      final tags = e['tags'] as Map<String, dynamic>?;
      if (tags == null) continue;

      final name = tags['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final coord = _coordOf(e);
      if (coord == null) continue;

      result.add(
        Attraction(
          name: name,
          location: coord,
          category: _categoryOf(tags),
          rating: _ratingOf(tags),
        ),
      );
    }
    return result;
  }

  GeoCoord? _coordOf(Map<String, dynamic> e) {
    if (e['lat'] != null && e['lon'] != null) {
      return GeoCoord(
        lat: (e['lat'] as num).toDouble(),
        lng: (e['lon'] as num).toDouble(),
      );
    }
    final center = e['center'] as Map<String, dynamic>?;
    if (center != null) {
      return GeoCoord(
        lat: (center['lat'] as num).toDouble(),
        lng: (center['lon'] as num).toDouble(),
      );
    }
    return null;
  }

  String _categoryOf(Map<String, dynamic> tags) {
    for (final key in ['tourism', 'natural', 'historic', 'leisure', 'waterway']) {
      if (tags[key] != null) return tags[key] as String;
    }
    return 'attraction';
  }

  /// Heuristic 0..5 "importance" rating from OSM metadata. Named landmarks with
  /// a Wikidata/Wikipedia link or higher-tier category score higher.
  double _ratingOf(Map<String, dynamic> tags) {
    var score = 2.5;
    if (tags['wikidata'] != null || tags['wikipedia'] != null) score += 1.2;
    final category = _categoryOf(tags);
    const premium = {'viewpoint', 'waterfall', 'peak', 'castle', 'beach'};
    if (premium.contains(category)) score += 0.8;
    if (tags['tourism'] == 'attraction') score += 0.3;
    return score.clamp(0.0, 5.0);
  }
}
