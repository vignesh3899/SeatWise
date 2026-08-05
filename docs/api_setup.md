# API setup guide (free APIs only)

SeatWise uses four free data sources. Two need a key (OpenRouteService,
OpenWeather); the OpenStreetMap services and SunCalc need none.

## OpenRouteService (routing)

1. Sign up at <https://openrouteservice.org/dev/#/signup> (free).
2. Create a token under **Dashboard → Tokens**.
3. Put it in `.env` as `OPEN_ROUTE_API_KEY` (and in `functions/.env` /
   Firebase secrets for the Cloud Function).

Free tier: generous daily request quota, ample for development and light use.
The app uses the **Directions v2** GeoJSON endpoint.

## OpenWeather (weather)

1. Sign up at <https://home.openweathermap.org/users/sign_up> (free).
2. Copy your key from **API keys**. New keys can take a little while to activate.
3. Put it in `.env` as `OPEN_WEATHER_API_KEY`.

Free tier: **Current Weather** data. SeatWise samples current conditions at a few
points along the route (a good proxy for short/medium bus trips).

## OpenStreetMap Nominatim (geocoding) — no key

Used for the place search in the planner.

- Policy: <https://operations.osmfoundation.org/policies/nominatim/>
- **Max ~1 request/second** and a **descriptive User‑Agent** are required. The
  app enforces both (400 ms debounce + `SeatWise/1.0 …` User‑Agent).

## OpenStreetMap Overpass (points of interest) — no key

Used to find scenic attractions near the route (viewpoints, peaks, beaches,
castles, parks, museums, …). Queries are bounded to the route's bounding box and
capped at 200 results. Please be gentle with the shared public endpoint.

## SunCalc (sun position) — no key, no network

Implemented locally in `lib/engine/sun_calculator.dart` (Dart) and
`functions/src/engines/sunCalc.ts` (TypeScript). It computes the sun's azimuth
and altitude for any time and location, entirely offline.

## Where keys are read

- **Flutter app**: `lib/config/env.dart` reads the bundled `.env` asset via
  `flutter_dotenv`. Keys are never committed (`.env` is git‑ignored; a blank one
  ships so the app compiles).
- **Cloud Functions**: `functions/src/index.ts` reads Firebase **secrets**
  (`OPEN_ROUTE_API_KEY`, `OPEN_WEATHER_API_KEY`), falling back to
  `functions/.env` (`process.env`) during local emulation.
