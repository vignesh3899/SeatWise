import {logger} from 'firebase-functions/v2';
import {HttpsError} from 'firebase-functions/v2/https';

import {recommend} from '../engines/seatEngine';
import {
  Attraction,
  GeoCoord,
  RecommendRequest,
  SeatRecommendation,
  WeatherPoint,
} from '../models/types';
import {getRoute} from '../services/openRouteService';
import {weatherForPoints} from '../services/openWeatherService';
import {findAttractions} from '../services/overpassService';
import {boundingBox, sampleRoute, samplePoints} from '../utils/route';

/**
 * Validates the request, runs the full pipeline (route → weather + attractions
 * → engine) and returns a {@link SeatRecommendation}. Weather and attraction
 * lookups fail soft so a single flaky upstream never blocks the result.
 */
export async function handleRecommend(
  data: unknown,
  keys: {ors: string; weather: string}
): Promise<SeatRecommendation> {
  const request = parseRequest(data);

  if (!keys.ors) {
    throw new HttpsError(
      'failed-precondition',
      'OpenRouteService key is not configured on the server.'
    );
  }

  const route = await getRoute(keys.ors, request.origin, request.destination);
  const segments = sampleRoute(route);

  let weather: WeatherPoint[] = [];
  if (keys.weather) {
    try {
      weather = await weatherForPoints(
        keys.weather,
        samplePoints(route.polyline, 4)
      );
    } catch (e) {
      logger.warn('Weather lookup failed; continuing without it.', e);
    }
  }

  let attractions: Attraction[] = [];
  try {
    attractions = await findAttractions(boundingBox(route.polyline));
  } catch (e) {
    logger.warn('Attraction lookup failed; continuing without it.', e);
  }

  return recommend({
    segments,
    departure: new Date(request.departureIso),
    weatherSamples: weather,
    attractions,
    distanceMeters: route.distanceMeters,
    durationSeconds: route.durationSeconds,
    preferShade: request.preferShade,
  });
}

function parseRequest(data: unknown): RecommendRequest {
  const d = (data ?? {}) as Record<string, unknown>;
  const origin = parseCoord(d.origin, 'origin');
  const destination = parseCoord(d.destination, 'destination');
  const departureIso =
    typeof d.departureIso === 'string' && d.departureIso.length > 0
      ? d.departureIso
      : new Date().toISOString();
  if (Number.isNaN(new Date(departureIso).getTime())) {
    throw new HttpsError('invalid-argument', 'departureIso is not a valid date.');
  }
  const preferShade = d.preferShade === undefined ? true : Boolean(d.preferShade);
  return {origin, destination, departureIso, preferShade};
}

function parseCoord(value: unknown, field: string): GeoCoord {
  const v = value as Record<string, unknown> | undefined;
  const lat = Number(v?.lat);
  const lng = Number(v?.lng);
  if (
    !Number.isFinite(lat) ||
    !Number.isFinite(lng) ||
    lat < -90 ||
    lat > 90 ||
    lng < -180 ||
    lng > 180
  ) {
    throw new HttpsError(
      'invalid-argument',
      `${field} must be a { lat, lng } pair with valid coordinates.`
    );
  }
  return {lat, lng};
}
