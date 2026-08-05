import {GeoCoord} from '../models/types';

/**
 * SunCalc port (sun position only), mirroring the Dart `SunCalculator`.
 * Returns a compass azimuth (0 = north) and altitude in degrees.
 */

const rad = Math.PI / 180.0;
const obliquity = rad * 23.4397;
const dayMs = 86400000.0;
const J1970 = 2440588.0;
const J2000 = 2451545.0;

const toDays = (dateUtc: Date): number =>
  dateUtc.getTime() / dayMs - 0.5 + J1970 - J2000;

const rightAscension = (l: number, b: number): number =>
  Math.atan2(
    Math.sin(l) * Math.cos(obliquity) - Math.tan(b) * Math.sin(obliquity),
    Math.cos(l)
  );

const declination = (l: number, b: number): number =>
  Math.asin(
    Math.sin(b) * Math.cos(obliquity) +
      Math.cos(b) * Math.sin(obliquity) * Math.sin(l)
  );

const azimuthFromSouth = (h: number, phi: number, dec: number): number =>
  Math.atan2(
    Math.sin(h),
    Math.cos(h) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi)
  );

const altitude = (h: number, phi: number, dec: number): number =>
  Math.asin(
    Math.sin(phi) * Math.sin(dec) +
      Math.cos(phi) * Math.cos(dec) * Math.cos(h)
  );

const siderealTime = (d: number, lw: number): number =>
  rad * (280.16 + 360.9856235 * d) - lw;

const solarMeanAnomaly = (d: number): number =>
  rad * (357.5291 + 0.98560028 * d);

const eclipticLongitude = (m: number): number => {
  const c =
    rad *
    (1.9148 * Math.sin(m) + 0.02 * Math.sin(2 * m) + 0.0003 * Math.sin(3 * m));
  const perihelion = rad * 102.9372;
  return m + c + perihelion + Math.PI;
};

export interface SunPosition {
  azimuthDegrees: number;
  altitudeDegrees: number;
}

export function sunPosition(dateUtc: Date, coord: GeoCoord): SunPosition {
  const lw = rad * -coord.lng;
  const phi = rad * coord.lat;
  const d = toDays(dateUtc);

  const m = solarMeanAnomaly(d);
  const l = eclipticLongitude(m);
  const dec = declination(l, 0);
  const ra = rightAscension(l, 0);
  const h = siderealTime(d, lw) - ra;

  let compass = azimuthFromSouth(h, phi, dec) / rad + 180.0;
  compass %= 360.0;
  if (compass < 0) compass += 360.0;

  return {azimuthDegrees: compass, altitudeDegrees: altitude(h, phi, dec) / rad};
}
