# Testing guide

SeatWise ships unit, widget and integration tests, plus a type‑checked
TypeScript engine that mirrors the Dart one.

## Run everything

```bash
flutter pub get
flutter test                                   # unit + widget
flutter test integration_test/app_test.dart    # primary journey flow
cd functions && npm install && npm run build    # type-check the cloud engine
```

## What's covered

### Unit tests (`test/`)

- `engine/geo_test.dart` — haversine distance, bearings, left/right side math,
  angle normalisation.
- `engine/sun_calculator_test.dart` — sun is high & ~south at local noon, below
  the horizon at midnight, eastern in the morning.
- `engine/seat_engine_test.dart` — the core business logic:
  - empty route → neutral "either",
  - midday eastbound (sun on the right) → recommends the shaded **left**,
  - flipping the shade preference → recommends **right**,
  - night trip → "either" with an after‑sunset explanation,
  - determinism for identical input.
- `models/seat_recommendation_test.dart` — JSON round‑trip and crowd‑label
  thresholds.

### Widget tests (`test/widget/`)

- `seat_side_card_test.dart` — the hero card renders the headline and the ETA /
  crowd / confidence chips; the score comparison renders all four rows.

### Integration test (`integration_test/`)

- `app_test.dart` — drives the **planner → recommendation** flow with a stubbed
  repository (no network, no Firebase), asserting the recommendation headline and
  explanation appear.

## Cross‑language engine parity

The recommendation algorithm exists in Dart (`lib/engine/`) and TypeScript
(`functions/src/engines/`). Both are pure and deterministic, so the same inputs
produce the same LEFT/RIGHT decision. The Dart unit tests pin the behaviour; the
TypeScript version is type‑checked by `npm run build`.

## Coverage

```bash
flutter test --coverage
# open coverage/lcov.info with your preferred viewer, e.g.:
# genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

## Notes

- The unit/widget tests do **not** require Firebase or network access.
- Full end‑to‑end runs against real Firebase require a configured project and a
  connected device/emulator.
