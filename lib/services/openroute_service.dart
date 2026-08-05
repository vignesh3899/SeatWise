import 'dart:convert';

import '../config/env.dart';
import '../core/exceptions.dart';
import '../models/geo_coord.dart';
import '../models/route_data.dart';
import 'api_client.dart';
import 'package:http/http.dart' as http;

class OpenRouteService {
  OpenRouteService(this._client);

  final ApiClient _client;

  Future<RouteData> getRoute({
    required GeoCoord origin,
    required GeoCoord destination,
    String profile = 'driving-car',
  }) async {
    if (!Env.hasRoutingKey) {
      throw ApiException('OpenRouteService API key is not configured.');
    }

    final uri = Uri.https(
      'api.openrouteservice.org',
      '/v2/directions/$profile/geojson',
    );

    final body = {
      'coordinates': [
        [origin.lng, origin.lat],
        [destination.lng, destination.lat],
      ],
      'instructions': false,
      'elevation': false,
    };

    print('========== ORS REQUEST ==========');
    print(uri);
    print(jsonEncode(body));
    print('API KEY: ${Env.openRouteApiKey}');
    print('=================================');

    

  final response = await http.post(
  uri,
  headers: {
    'Authorization': Env.openRouteApiKey.trim(),
    'Content-Type': 'application/json',
  },
  body: jsonEncode(body),
);

print("STATUS: ${response.statusCode}");
print("BODY: ${response.body}");
if (response.statusCode != 200) {
  throw ApiException(response.body);
}

final json = jsonDecode(response.body);

return RouteData.fromOrsJson(json as Map<String, dynamic>);
  }
}