import {Attraction, ENGINE, GeoCoord} from '../models/types';
import {BBox} from '../utils/route';

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';

const SCENIC_KEYS = [
  'tourism~"^(viewpoint|attraction|artwork|museum|gallery|zoo|theme_park)$"',
  'natural~"^(peak|beach|water|waterfall|bay|cliff|volcano)$"',
  'historic~"^(castle|monument|ruins|memorial|fort|archaeological_site)$"',
  'leisure~"^(park|nature_reserve|garden)$"',
  'waterway~"^(waterfall)$"',
];

/** Finds scenic OSM POIs inside [bbox] via the Overpass API. */
export async function findAttractions(bbox: BBox): Promise<Attraction[]> {
  const box = `${bbox.south},${bbox.west},${bbox.north},${bbox.east}`;
  const clauses = SCENIC_KEYS.map(
    (k) => `node[${k}](${box});way[${k}](${box});`
  ).join('\n');
  const query = `[out:json][timeout:25];\n(\n${clauses}\n);\nout center 200;`;

  const response = await fetch(OVERPASS_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': ENGINE.httpUserAgent,
    },
    body: `data=${encodeURIComponent(query)}`,
  });
  if (!response.ok) throw new Error(`Overpass HTTP ${response.status}`);

  const json = (await response.json()) as OverpassResponse;
  const result: Attraction[] = [];
  for (const el of json.elements ?? []) {
    const tags = el.tags;
    if (!tags?.name) continue;
    const coord = coordOf(el);
    if (!coord) continue;
    result.push({
      name: tags.name,
      location: coord,
      category: categoryOf(tags),
      rating: ratingOf(tags),
      side: 'either',
      distanceFromRouteMeters: 0,
    });
  }
  return result;
}

function coordOf(el: OverpassElement): GeoCoord | null {
  if (el.lat != null && el.lon != null) return {lat: el.lat, lng: el.lon};
  if (el.center) return {lat: el.center.lat, lng: el.center.lon};
  return null;
}

function categoryOf(tags: Record<string, string>): string {
  for (const key of ['tourism', 'natural', 'historic', 'leisure', 'waterway']) {
    if (tags[key]) return tags[key];
  }
  return 'attraction';
}

function ratingOf(tags: Record<string, string>): number {
  let score = 2.5;
  if (tags.wikidata || tags.wikipedia) score += 1.2;
  const category = categoryOf(tags);
  if (['viewpoint', 'waterfall', 'peak', 'castle', 'beach'].includes(category)) {
    score += 0.8;
  }
  if (tags.tourism === 'attraction') score += 0.3;
  return Math.max(0, Math.min(5, score));
}

interface OverpassElement {
  lat?: number;
  lon?: number;
  center?: {lat: number; lon: number};
  tags?: Record<string, string>;
}

interface OverpassResponse {
  elements?: OverpassElement[];
}
