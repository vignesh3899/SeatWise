import {ENGINE, GeoCoord, RouteData} from '../models/types';

const ORS_BASE = 'https://api.openrouteservice.org';

/** Fetches a driving route from OpenRouteService (GeoJSON endpoint). */
export async function getRoute(
  apiKey: string,
  origin: GeoCoord,
  destination: GeoCoord,
  profile = 'driving-car'
): Promise<RouteData> {
  const response = await fetch(
    `${ORS_BASE}/v2/directions/${profile}/geojson`,
    {
      method: 'POST',
      headers: {
        Authorization: apiKey,
        'Content-Type': 'application/json; charset=utf-8',
        'User-Agent': ENGINE.httpUserAgent,
      },
      body: JSON.stringify({
        coordinates: [
          [origin.lng, origin.lat],
          [destination.lng, destination.lat],
        ],
        instructions: false,
        elevation: false,
      }),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OpenRouteService HTTP ${response.status}: ${text.slice(0, 180)}`);
  }

  const json = (await response.json()) as OrsResponse;
  const feature = json.features?.[0];
  if (!feature) throw new Error('OpenRouteService returned no route.');

  const polyline: GeoCoord[] = feature.geometry.coordinates.map(
    ([lng, lat]) => ({lat, lng})
  );
  return {
    polyline,
    distanceMeters: feature.properties.summary.distance,
    durationSeconds: feature.properties.summary.duration,
  };
}

interface OrsResponse {
  features?: Array<{
    geometry: {coordinates: [number, number][]};
    properties: {summary: {distance: number; duration: number}};
  }>;
}
