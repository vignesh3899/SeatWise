import {GeoCoord} from '../models/types';

/** Pure geodesy helpers, mirroring the Dart `Geo` class. */

const EARTH_RADIUS_M = 6371000.0;
const toRad = (deg: number): number => (deg * Math.PI) / 180.0;
const toDeg = (rad: number): number => (rad * 180.0) / Math.PI;

export function distanceMeters(a: GeoCoord, b: GeoCoord): number {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1.0, Math.sqrt(h)));
}

export function bearingDegrees(from: GeoCoord, to: GeoCoord): number {
  const lat1 = toRad(from.lat);
  const lat2 = toRad(to.lat);
  const dLng = toRad(to.lng - from.lng);
  const y = Math.sin(dLng) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  return (toDeg(Math.atan2(y, x)) + 360.0) % 360.0;
}

export function normalizeSignedDegrees(deg: number): number {
  let d = (deg + 180.0) % 360.0;
  if (d < 0) d += 360.0;
  return d - 180.0;
}

/** +1 = right of travel, -1 = left, 0 = straight ahead/behind. */
export function sideOfHeading(heading: number, targetBearing: number): number {
  const rel = normalizeSignedDegrees(targetBearing - heading);
  if (Math.abs(rel) < 1.0 || 180.0 - Math.abs(rel) < 1.0) return 0;
  return rel > 0 ? 1 : -1;
}

export function crossTrackDistanceMeters(
  a: GeoCoord,
  b: GeoCoord,
  p: GeoCoord
): number {
  const d13 = distanceMeters(a, p) / EARTH_RADIUS_M;
  const theta13 = toRad(bearingDegrees(a, p));
  const theta12 = toRad(bearingDegrees(a, b));
  const dxt = Math.asin(Math.sin(d13) * Math.sin(theta13 - theta12));
  return Math.abs(dxt * EARTH_RADIUS_M);
}

export function midpoint(a: GeoCoord, b: GeoCoord): GeoCoord {
  return {lat: (a.lat + b.lat) / 2, lng: (a.lng + b.lng) / 2};
}
