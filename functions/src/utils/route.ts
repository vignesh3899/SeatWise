import {ENGINE, GeoCoord, RouteData, RouteSegment} from '../models/types';
import {bearingDegrees, distanceMeters, midpoint} from './geo';

/** Merges polyline vertices into ~evenly-sized segments (mirrors Dart). */
export function sampleRoute(route: RouteData): RouteSegment[] {
  const points = route.polyline;
  if (points.length < 2) return [];

  const avgSpeed =
    route.durationSeconds > 0
      ? route.distanceMeters / route.durationSeconds
      : 12.0;

  const segments: RouteSegment[] = [];
  let anchor = points[0];
  let accumulated = 0.0;
  let travelled = 0.0;

  for (let i = 1; i < points.length; i++) {
    const current = points[i];
    const step = distanceMeters(points[i - 1], current);
    accumulated += step;
    travelled += step;

    const isLast = i === points.length - 1;
    if (accumulated >= ENGINE.segmentSampleMeters || isLast) {
      const midTravelled = travelled - accumulated / 2;
      segments.push({
        start: anchor,
        end: current,
        midpoint: midpoint(anchor, current),
        headingDegrees: bearingDegrees(anchor, current),
        lengthMeters: accumulated,
        cumulativeSeconds: avgSpeed > 0 ? midTravelled / avgSpeed : 0,
      });
      anchor = current;
      accumulated = 0.0;
    }
  }
  return segments;
}

export interface BBox {
  south: number;
  west: number;
  north: number;
  east: number;
}

export function boundingBox(points: GeoCoord[], padMeters = 1500): BBox {
  let south = points[0].lat;
  let north = points[0].lat;
  let west = points[0].lng;
  let east = points[0].lng;
  for (const p of points) {
    south = Math.min(south, p.lat);
    north = Math.max(north, p.lat);
    west = Math.min(west, p.lng);
    east = Math.max(east, p.lng);
  }
  const padLat = padMeters / 111000.0;
  const midLatRad = ((south + north) / 2) * (Math.PI / 180.0);
  const cosLat = Math.max(0.05, Math.abs(Math.cos(midLatRad)));
  const padLng = padMeters / (111000.0 * cosLat);
  return {
    south: south - padLat,
    west: west - padLng,
    north: north + padLat,
    east: east + padLng,
  };
}

/** Evenly spaced sample coordinates along a polyline (including both ends). */
export function samplePoints(polyline: GeoCoord[], count: number): GeoCoord[] {
  if (polyline.length <= count) return polyline;
  const result: GeoCoord[] = [];
  for (let i = 0; i < count; i++) {
    const idx = Math.round(((polyline.length - 1) * i) / (count - 1));
    result.push(polyline[idx]);
  }
  return result;
}
