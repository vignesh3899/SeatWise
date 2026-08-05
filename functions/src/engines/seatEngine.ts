import {
  Attraction,
  ENGINE,
  RouteSegment,
  SeatRecommendation,
  SeatSide,
  SideScores,
  WeatherPoint,
} from '../models/types';
import {
  bearingDegrees,
  crossTrackDistanceMeters,
  normalizeSignedDegrees,
  sideOfHeading,
} from '../utils/geo';
import {sunPosition} from './sunCalc';

export interface EngineInput {
  segments: RouteSegment[];
  departure: Date;
  weatherSamples: WeatherPoint[];
  attractions: Attraction[];
  distanceMeters: number;
  durationSeconds: number;
  preferShade: boolean;
}

const clamp = (v: number, lo: number, hi: number): number =>
  Math.max(lo, Math.min(hi, v));

const clearness = (w: WeatherPoint): number =>
  clamp(1.0 - w.cloudPercent / 100.0, 0, 1);

const isRaining = (w: WeatherPoint): boolean =>
  w.condition.toLowerCase().includes('rain') || w.rainMmPerHour > 0;

/** Server-side twin of the Dart `SeatEngine`. Deterministic and pure. */
export function recommend(input: EngineInput): SeatRecommendation {
  const {segments} = input;
  if (segments.length === 0) {
    return neutral(input, 'We could not read the route geometry.');
  }

  // 1. Sun / shade load per side.
  let leftSunLoad = 0;
  let rightSunLoad = 0;
  let daylightWeight = 0;
  let totalWeight = 0;
  let sunOnRightWeight = 0;

  segments.forEach((seg, index) => {
    const weight = Math.max(seg.lengthMeters, 1.0);
    totalWeight += weight;

    const time = new Date(
      input.departure.getTime() + seg.cumulativeSeconds * 1000
    );
    const sun = sunPosition(time, seg.midpoint);
    if (sun.altitudeDegrees <= 0) return;

    const weather = weatherForSegment(input, index, segments.length);
    const sky = weather ? clearness(weather) : 0.8;

    const altRad = (sun.altitudeDegrees * Math.PI) / 180.0;
    const illumination = Math.max(0, Math.sin(altRad));
    const laterality = Math.abs(Math.cos(altRad));
    const rel = normalizeSignedDegrees(sun.azimuthDegrees - seg.headingDegrees);
    const perpendicular = Math.abs(Math.sin((rel * Math.PI) / 180.0));

    const load =
      weight * illumination * (0.35 + 0.65 * laterality) * perpendicular * sky;
    daylightWeight += weight * illumination;

    const side = sideOfHeading(seg.headingDegrees, sun.azimuthDegrees);
    if (side > 0) {
      rightSunLoad += load;
      sunOnRightWeight += weight;
    } else if (side < 0) {
      leftSunLoad += load;
    }
  });

  const sunOnRightFraction =
    totalWeight > 0 ? sunOnRightWeight / totalWeight : 0.5;
  const totalLoad = leftSunLoad + rightSunLoad;
  const isDaylightTrip = daylightWeight > totalWeight * 0.05;

  let comfortLeft: number;
  let comfortRight: number;
  if (totalLoad < 1e-6) {
    comfortLeft = 50;
    comfortRight = 50;
  } else {
    const rightShare = rightSunLoad / totalLoad;
    const leftShare = leftSunLoad / totalLoad;
    if (input.preferShade) {
      comfortLeft = 100 * rightShare;
      comfortRight = 100 * leftShare;
    } else {
      comfortLeft = 100 * leftShare;
      comfortRight = 100 * rightShare;
    }
  }

  // 2. Scenic score per side.
  const sided = assignSides(input.attractions, segments);
  let scenicLeftRaw = 0;
  let scenicRightRaw = 0;
  for (const a of sided) {
    const proximity = clamp(
      1.0 - a.distanceFromRouteMeters / ENGINE.attractionSearchRadiusMeters,
      0,
      1
    );
    const value = (a.rating ?? 2.5) * (0.4 + 0.6 * proximity);
    if (a.side === 'left') scenicLeftRaw += value;
    else if (a.side === 'right') scenicRightRaw += value;
  }
  const scenicTotal = scenicLeftRaw + scenicRightRaw;
  const scenicLeft = scenicTotal < 1e-6 ? 50 : (100 * scenicLeftRaw) / scenicTotal;
  const scenicRight =
    scenicTotal < 1e-6 ? 50 : (100 * scenicRightRaw) / scenicTotal;

  // 3. Weather-driven comfort.
  const weatherPair = weatherScores(
    input,
    leftSunLoad <= rightSunLoad,
    isDaylightTrip
  );

  // 4. Blend.
  const left = makeSide(comfortLeft, scenicLeft, weatherPair.left);
  const right = makeSide(comfortRight, scenicRight, weatherPair.right);

  const gap = Math.abs(left.total - right.total);
  let side: SeatSide;
  if (gap < ENGINE.tieThreshold) side = 'either';
  else side = left.total > right.total ? 'left' : 'right';
  const confidence = clamp(gap / 25.0, 0, 1);

  const crowd = estimateCrowd(input.departure, input.distanceMeters);
  const reasons = buildReasons(
    side,
    input,
    left,
    right,
    sunOnRightFraction,
    isDaylightTrip,
    sided,
    crowd
  );

  return {
    recommendedSide: side,
    confidence,
    leftScores: left,
    rightScores: right,
    headline: headline(side),
    reasons,
    etaSeconds: input.durationSeconds,
    crowdLevel: crowd,
    sunOnRightFraction,
    attractions: sided,
    weatherSamples: input.weatherSamples,
  };
}

function makeSide(comfort: number, scenic: number, weather: number): SideScores {
  const total = clamp(
    ENGINE.weightComfort * comfort +
      ENGINE.weightScenic * scenic +
      ENGINE.weightWeather * weather,
    0,
    100
  );
  return {comfort, scenic, weather, total};
}

function weatherForSegment(
  input: EngineInput,
  index: number,
  segmentCount: number
): WeatherPoint | null {
  if (input.weatherSamples.length === 0) return null;
  const fraction = segmentCount > 1 ? index / (segmentCount - 1) : 0;
  const sampleIndex = Math.min(
    input.weatherSamples.length - 1,
    Math.max(0, Math.round(fraction * (input.weatherSamples.length - 1)))
  );
  return input.weatherSamples[sampleIndex];
}

function assignSides(
  attractions: Attraction[],
  segments: RouteSegment[]
): Attraction[] {
  const result: Attraction[] = [];
  for (const a of attractions) {
    let nearest: RouteSegment | null = null;
    let nearestDist = Number.POSITIVE_INFINITY;
    for (const seg of segments) {
      const d = crossTrackDistanceMeters(seg.start, seg.end, a.location);
      if (d < nearestDist) {
        nearestDist = d;
        nearest = seg;
      }
    }
    if (!nearest) continue;
    const bearingToA = bearingDegrees(nearest.midpoint, a.location);
    const sign = sideOfHeading(nearest.headingDegrees, bearingToA);
    const side: SeatSide = sign > 0 ? 'right' : sign < 0 ? 'left' : 'either';
    result.push({...a, side, distanceFromRouteMeters: nearestDist});
  }
  result.sort((x, y) => (y.rating ?? 0) - (x.rating ?? 0));
  return result.filter(
    (a) => a.distanceFromRouteMeters <= ENGINE.attractionSearchRadiusMeters
  );
}

function weatherScores(
  input: EngineInput,
  leftIsShade: boolean,
  isDaylightTrip: boolean
): {left: number; right: number} {
  if (input.weatherSamples.length === 0 || !isDaylightTrip) {
    return {left: 50, right: 50};
  }
  const avgTemp =
    input.weatherSamples.reduce((s, w) => s + w.temperatureC, 0) /
    input.weatherSamples.length;
  const avgClearness =
    input.weatherSamples.reduce((s, w) => s + clearness(w), 0) /
    input.weatherSamples.length;

  const heatFactor = clamp((avgTemp - 22.0) / 13.0, 0, 1);
  const advantage = heatFactor * avgClearness * 25.0;
  const signed = input.preferShade ? advantage : -advantage;
  const shadeLeft = leftIsShade ? 50 + signed : 50 - signed;
  return {left: clamp(shadeLeft, 0, 100), right: clamp(100 - shadeLeft, 0, 100)};
}

function estimateCrowd(departure: Date, distanceMeters: number): number {
  const hour = departure.getHours();
  let base: number;
  if ((hour >= 7 && hour <= 10) || (hour >= 17 && hour <= 20)) base = 0.8;
  else if (hour >= 11 && hour <= 16) base = 0.5;
  else if (hour >= 21 || hour <= 5) base = 0.25;
  else base = 0.45;
  const lengthFactor = clamp(distanceMeters / 60000.0, 0, 0.15);
  return clamp(base + lengthFactor, 0, 1);
}

function crowdLabel(crowd: number): string {
  if (crowd < 0.34) return 'Light';
  if (crowd < 0.67) return 'Moderate';
  return 'Busy';
}

function formatDuration(seconds: number): string {
  const total = Math.round(seconds);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  return hours <= 0 ? `${minutes}m` : `${hours}h ${minutes}m`;
}

function buildReasons(
  side: SeatSide,
  input: EngineInput,
  left: SideScores,
  right: SideScores,
  sunOnRightFraction: number,
  isDaylightTrip: boolean,
  attractions: Attraction[],
  crowd: number
): string[] {
  const reasons: string[] = [];
  const sunnySide = sunOnRightFraction >= 0.5 ? 'right' : 'left';
  const shadeSide = sunnySide === 'right' ? 'left' : 'right';
  const sunnyPct =
    (sunOnRightFraction >= 0.5 ? sunOnRightFraction : 1 - sunOnRightFraction) *
    100;

  if (isDaylightTrip) {
    reasons.push(
      `The sun is on the ${sunnySide} for about ${Math.round(
        sunnyPct
      )}% of the trip, so the ${shadeSide} side stays shadier and cooler.`
    );
  } else {
    reasons.push(
      'Most of this trip happens after sunset, so sun and shade barely affect ' +
        'your comfort.'
    );
  }

  const scenicSide = right.scenic > left.scenic ? 'right' : 'left';
  const picks = attractions
    .filter((a) => a.side === scenicSide)
    .slice(0, 3)
    .map((a) => a.name);
  if (picks.length > 0) {
    reasons.push(
      `Scenic highlights on the ${scenicSide} include ${picks.join(', ')}.`
    );
  } else if (attractions.length === 0) {
    reasons.push('No standout landmarks were found close to this route.');
  }

  if (input.weatherSamples.length > 0) {
    const w = input.weatherSamples[0];
    if (isRaining(w)) {
      reasons.push(
        `Rain is likely along the way (${w.description}); expect some window ` +
          'streaking on both sides.'
      );
    } else if (w.temperatureC >= 30) {
      reasons.push(
        `It is hot (~${Math.round(
          w.temperatureC
        )}°C), which makes the shaded side noticeably more comfortable.`
      );
    } else {
      reasons.push(
        `Weather looks ${
          w.description || w.condition.toLowerCase()
        } (~${Math.round(w.temperatureC)}°C).`
      );
    }
  }

  reasons.push(
    `Estimated travel time is ${formatDuration(
      input.durationSeconds
    )}, with a ${crowdLabel(crowd).toLowerCase()} expected crowd.`
  );

  if (side === 'either') {
    reasons.push('The two sides are very close, so pick whichever seat you like.');
  }
  return reasons;
}

function headline(side: SeatSide): string {
  switch (side) {
    case 'left':
      return 'Sit on the LEFT for the best ride';
    case 'right':
      return 'Sit on the RIGHT for the best ride';
    default:
      return 'Either side works for this trip';
  }
}

function neutral(input: EngineInput, why: string): SeatRecommendation {
  const scores: SideScores = {comfort: 50, scenic: 50, weather: 50, total: 50};
  return {
    recommendedSide: 'either',
    confidence: 0,
    leftScores: scores,
    rightScores: scores,
    headline: 'Either side works for this trip',
    reasons: [why],
    etaSeconds: input.durationSeconds,
    crowdLevel: estimateCrowd(input.departure, input.distanceMeters),
    sunOnRightFraction: 0.5,
    attractions: [],
    weatherSamples: input.weatherSamples,
  };
}
