/**
 * Shared types for the SeatWise Cloud Functions engine. The JSON produced by
 * {@link SeatRecommendation} intentionally matches the Dart client's
 * `SeatRecommendation.fromJson`, so the app can parse a cloud result exactly as
 * it parses an on-device one.
 */

export interface GeoCoord {
  lat: number;
  lng: number;
}

export type SeatSide = 'left' | 'right' | 'either';

export interface RouteData {
  polyline: GeoCoord[];
  distanceMeters: number;
  durationSeconds: number;
}

export interface RouteSegment {
  start: GeoCoord;
  end: GeoCoord;
  midpoint: GeoCoord;
  headingDegrees: number;
  lengthMeters: number;
  cumulativeSeconds: number;
}

export interface WeatherPoint {
  temperatureC: number;
  cloudPercent: number;
  condition: string;
  description: string;
  icon: string;
  rainMmPerHour: number;
}

export interface Attraction {
  name: string;
  location: GeoCoord;
  category: string;
  rating: number | null;
  side: SeatSide;
  distanceFromRouteMeters: number;
}

export interface SideScores {
  comfort: number;
  scenic: number;
  weather: number;
  total: number;
}

export interface SeatRecommendation {
  recommendedSide: SeatSide;
  confidence: number;
  leftScores: SideScores;
  rightScores: SideScores;
  headline: string;
  reasons: string[];
  etaSeconds: number;
  crowdLevel: number;
  sunOnRightFraction: number;
  attractions: Attraction[];
  weatherSamples: WeatherPoint[];
}

export interface RecommendRequest {
  origin: GeoCoord;
  destination: GeoCoord;
  departureIso: string;
  preferShade: boolean;
}

/** Engine tuning constants — kept in sync with the Dart `AppConstants`. */
export const ENGINE = {
  attractionSearchRadiusMeters: 1500,
  segmentSampleMeters: 2000,
  weightComfort: 0.45,
  weightScenic: 0.35,
  weightWeather: 0.2,
  tieThreshold: 4.0,
  httpUserAgent: 'SeatWise/1.0 (https://github.com/seatwise/seatwise)',
} as const;
