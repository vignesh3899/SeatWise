import {ENGINE, GeoCoord, WeatherPoint} from '../models/types';

const OW_BASE = 'https://api.openweathermap.org/data/2.5';

/** Current weather at a single point. */
async function weatherAt(
  apiKey: string,
  coord: GeoCoord
): Promise<WeatherPoint> {
  const url =
    `${OW_BASE}/weather?lat=${coord.lat}&lon=${coord.lng}` +
    `&units=metric&appid=${apiKey}`;
  const response = await fetch(url, {
    headers: {'User-Agent': ENGINE.httpUserAgent},
  });
  if (!response.ok) {
    throw new Error(`OpenWeather HTTP ${response.status}`);
  }
  const json = (await response.json()) as OwResponse;
  const weather = json.weather?.[0];
  return {
    temperatureC: json.main?.temp ?? 0,
    cloudPercent: json.clouds?.all ?? 0,
    condition: weather?.main ?? 'Unknown',
    description: weather?.description ?? '',
    icon: weather?.icon ?? '01d',
    rainMmPerHour: json.rain?.['1h'] ?? 0,
  };
}

/** Fetches weather for several points, resolving in parallel. */
export async function weatherForPoints(
  apiKey: string,
  points: GeoCoord[]
): Promise<WeatherPoint[]> {
  return Promise.all(points.map((p) => weatherAt(apiKey, p)));
}

interface OwResponse {
  weather?: Array<{main: string; description: string; icon: string}>;
  main?: {temp: number};
  clouds?: {all: number};
  rain?: {'1h'?: number};
}
